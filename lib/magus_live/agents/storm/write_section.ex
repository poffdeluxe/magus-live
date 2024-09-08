defmodule MagusLive.Agents.Storm.WriteSection do
  alias LangChain.Message
  alias LangChain.PromptTemplate
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState
  alias MagusLive.Agents.Storm.Util
  alias MagusLive.SemanticSearch

  @json_schema_path "agent_schema/storm/write_section.json"

  @base_prompt_template ~S|
You are an expert Wikipedia writer. Complete your assigned section from the following outline:
<%= @outline %>

Cite your sources, using the following references:

<Documents>
  <%= @documents %>
</Documents>
|

  def get_fn do
    write_section_template =
      PromptTemplate.from_template!(@base_prompt_template)

    path = Path.join(:code.priv_dir(:magus_live), @json_schema_path)
    {:ok, schema_file} = File.read(path)
    section_schema = Poison.decode!(schema_file)

    write_section = fn chain, state ->
      {section, sections_to_write} = List.pop_at(state.sections_to_write, 0)

      search_query = "#{state.topic}: #{section["section_title"]}"
      docs = SemanticSearch.search(state.doc_store_pid, search_query)
        |> Enum.map(fn {doc, _distance} -> doc end)

      {:ok, written_section, _response} =
        chain
        |> AgentChain.add_message(
          Message.new_system!(
          PromptTemplate.format(write_section_template, %{
            outline: Util.outline_as_str(state.original_outline),
            documents: docs_as_str(docs)
          }))
        )
        |> AgentChain.add_message(Message.new_user!("Write the full section for the #{section["section_title"]} section."))
        |> AgentChain.ask_for_json_response(section_schema)
        |> AgentChain.run()

      %StormState{state | sections_to_write: sections_to_write, written_sections: state.written_sections ++ [written_section]}
    end

    write_section
  end

  defp docs_as_str(docs) do
    docs
    |> Enum.map(fn %SemanticSearch.Document{source: href, content: content} = _doc ->
      "<Document href=\"#{href}\">\n#{content}\n</Document>"
    end)
    |> Enum.join("\n")
  end
end
