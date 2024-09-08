defmodule MagusLive.Agents.Storm.GenerateOutline do
  alias Expo.Message
  alias MagusLive.Agents.StormState

  alias Magus.AgentChain
  alias LangChain.Message
  alias LangChain.PromptTemplate

  @json_schema_path "agent_schema/storm/generate_outline.json"

  @base_prompt_template ~S|
  You are a Wikipedia writer. Write an outline for a Wikipedia page about a user-provided topic. Be comprehensive and specific. The topic is: <%= @topic %>.
  |

  def get_fn() do
    generate_outline_template =
      PromptTemplate.from_template!(@base_prompt_template)

    path = Path.join(:code.priv_dir(:magus_live), @json_schema_path)
    {:ok, schema_file} = File.read(path)
    outline_schema = Poison.decode!(schema_file)

    generate_outline = fn chain, state ->
      {:ok, outline, _response} =
        chain
        |> AgentChain.add_message(Message.new_system!(PromptTemplate.format(generate_outline_template, state)))
        |> AgentChain.ask_for_json_response(outline_schema)
        |> AgentChain.run()

      %StormState{state | original_outline: outline}
    end

    generate_outline
  end
end
