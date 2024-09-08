defmodule MagusLive.Agents.Storm.WriteArticle do
  alias LangChain.Message
  alias LangChain.PromptTemplate
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState
  alias MagusLive.Agents.Storm.Util

  @base_prompt_template ~S|
You are an expert Wikipedia author. Write the complete wiki article on <%= @topic %> using the following section drafts:
<%= @draft %>

Strictly follow Wikipedia format guidelines.
|

  def get_fn do
    write_article_template =
      PromptTemplate.from_template!(@base_prompt_template)

    write_article = fn chain, state ->
      written_sections = state.written_sections

      draft = written_sections
        |> Enum.map(fn s -> Util.section_as_str(s) end)
        |> Enum.join("\n\n")

      {:ok, content, _response} =
        chain
        |> AgentChain.add_message(
          Message.new_system!(
          PromptTemplate.format(write_article_template, %{
            draft: draft,
            topic: state.topic
          }))
        )
        |> AgentChain.add_message(Message.new_user!("Write the complete Wiki article using markdown format. Organize citations using footnotes like \"[1]\" avoiding duplicates in the footer. Include all the referenced URLs in the footer."))
        |> AgentChain.run()

      %StormState{state | final_article: content |> String.trim()}
    end

    write_article
  end
end
