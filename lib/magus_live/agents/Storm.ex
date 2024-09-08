defmodule MagusLive.Agents.StormState do
  defstruct [
    :original_outline,
    :refined_outline,
    :topic,
    :expanded_topics,
    :editors,
    :current_interview,
    :doc_store_pid,
    :final_article,
    previous_interviews: [],
    sections_to_write: [],
    written_sections: [],
  ]
end

defmodule MagusLive.Agents.Storm do
  alias MagusLive.Agents.StormState
  alias MagusLive.Agents.Storm
  alias MagusLive.SemanticSearch
  alias MagusLive.SemanticSearch.Document
  alias Magus.GraphAgent

  def get_agent() do
    begin_interview = fn _llm, state ->
      {current_editor, remaining_editors} = state.editors |> List.pop_at(0)

      interview = %{
        messages: [{:sme, "So you said you were writing an article on #{state.topic}?"}],
        references_by_url: Map.new(),
        editor: current_editor,
        num_of_turns: 0
      }

      # Save the current inteview so we can reference it later
      previous_interviews =
        if state.current_interview do
          state.previous_interviews ++ [state.current_interview]
        else
          []
        end

      %StormState{
        state
        | editors: remaining_editors,
          current_interview: interview,
          previous_interviews: previous_interviews
      }
    end

    finalize_interviews = fn _llm, state ->
      # Clean up interview state now that we're done with them
      previous_interviews =
        if state.current_interview do
          state.previous_interviews ++ [state.current_interview]
        else
          []
        end

      %StormState{
        state
        | current_interview: nil,
          previous_interviews: previous_interviews
      }
    end

    build_doc_store = fn _llm, state ->
      {:ok, pid} = SemanticSearch.start()

      all_reference =
        List.flatten(
          state.previous_interviews
          |> Enum.map(fn interview -> Map.to_list(interview.references_by_url) end)
        )
        |> Enum.filter(fn {_url, content} -> content != nil end)

      # Add all references (as docs) to the index
      all_reference
      |> Enum.map(fn {url, content} -> %Document{content: content, source: url} end)
      |> Enum.each(fn doc -> SemanticSearch.add_document(pid, doc) end)

      %StormState{state | doc_store_pid: pid}
    end

    should_continue_interview = fn state ->
      # First, check if the interview is over or not
      # The interview is over if the max number of cycles is hit or if the model says the magic words
      current_interview = state.current_interview
      {:editor, last_message_from_editor} = state.current_interview.messages |> Enum.at(-2)

      # TODO: Make num_of_turns configurable
      should_continue_interview =
        current_interview.num_of_turns < 5 and
          not String.contains?(last_message_from_editor, "Thank you so much for your help!")

      cond do
        should_continue_interview ->
          :ask_question

        # If the interview isn't over, see if we have any other interviews left
        length(state.editors) > 0 ->
          :begin_interview

        # We're done with all interviews
        true ->
          :finalize_interviews
      end
    end

    should_continue_writing_sections = fn state ->
      case length(state.sections_to_write) > 0 do
        true -> :write_section
        false -> :write_article
      end
    end

    cleanup_fn = fn state ->
      case state.doc_store_pid do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end
    end

    %GraphAgent{
      name: "STORM",
      final_output_property: :final_article,
      initial_state: %StormState{},
      cleanup_fn: cleanup_fn
    }
    |> GraphAgent.add_node(:generate_outline, Storm.GenerateOutline.get_fn())
    |> GraphAgent.add_node(:expand_topics, Storm.ExpandTopics.get_fn())
    |> GraphAgent.add_node(:generate_editors, Storm.GenerateEditors.get_fn())
    |> GraphAgent.add_node(:begin_interview, begin_interview)
    |> GraphAgent.add_node(:ask_question, Storm.AskQuestion.get_fn())
    |> GraphAgent.add_node(:answer_question, Storm.AnswerQuestion.get_fn())
    |> GraphAgent.add_node(:finalize_interviews, finalize_interviews)
    |> GraphAgent.add_node(:refine_outline, Storm.RefineOutline.get_fn())
    |> GraphAgent.add_node(:build_doc_store, build_doc_store)
    |> GraphAgent.add_node(:write_section, Storm.WriteSection.get_fn())
    |> GraphAgent.add_node(:write_article, Storm.WriteArticle.get_fn())
    |> GraphAgent.set_entry_point(:generate_outline)
    |> GraphAgent.add_edge(:generate_outline, :expand_topics)
    |> GraphAgent.add_edge(:expand_topics, :generate_editors)
    |> GraphAgent.add_edge(:generate_editors, :begin_interview)
    |> GraphAgent.add_edge(:begin_interview, :ask_question)
    |> GraphAgent.add_edge(:ask_question, :answer_question)
    |> GraphAgent.add_conditional_edges(
      :answer_question,
      [:finalize_interviews, :ask_question, :begin_interview],
      should_continue_interview
    )
    |> GraphAgent.add_edge(:finalize_interviews, :refine_outline)
    |> GraphAgent.add_edge(:refine_outline, :build_doc_store)
    |> GraphAgent.add_edge(:build_doc_store, :write_section)
    |> GraphAgent.add_conditional_edges(
      :write_section,
      [:write_section, :write_article],
      should_continue_writing_sections
    )
    |> GraphAgent.add_edge(:write_article, :end)
  end
end
