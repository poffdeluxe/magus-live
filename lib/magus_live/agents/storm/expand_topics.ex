defmodule MagusLive.Agents.Storm.ExpandTopics do
  alias LangChain.PromptTemplate
  alias Magus.AgentChain
  alias MagusLive.Agents.StormState

  @base_prompt_template ~S|
  I'm writing a Wikipedia page for a topic mentioned below. Please identify and recommend some Wikipedia pages on closely related subjects. I'm looking for examples that provide insights into interesting aspects commonly associated with this topic, or examples that help me understand the typical content and structure included in Wikipedia pages for similar topics.

Please list the as many subjects you can.
The only response returned should be a comma-separated, single-line comprehensive list of related subjects as background research.

Topic of interest: <%= @topic %>
  |

  def get_fn do
    expand_topics_template =
      PromptTemplate.from_template!(@base_prompt_template)

    expand_topics = fn chain, state ->
      {:ok, content, _response} =
        chain
        |> AgentChain.add_message(PromptTemplate.to_message!(expand_topics_template, state))
        |> AgentChain.run()

      %StormState{state | expanded_topics: String.split(content, ", ")}
    end

    expand_topics
  end
end
