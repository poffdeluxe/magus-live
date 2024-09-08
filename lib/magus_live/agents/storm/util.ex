defmodule MagusLive.Agents.Storm.Util do
  def outline_as_str(outline) do
    sections = outline["sections"]
    |> Enum.map(fn section -> section_as_str(section) end)
    |> Enum.join("\n\n")

    String.trim("# #{outline["page_title"]}\n\n#{sections}")
  end

  def section_as_str(section) do
    subsections = if Map.has_key?(section, "subsections") do
      section["subsections"]
        |> Enum.map(fn subsection -> subsection_as_str(subsection) end)
        |> Enum.join("\n\n")
    else
      ""
    end

    content_key = if Map.has_key?(section, "description") do
      "description"
    else
      "content"
    end

    citations = if Map.has_key?(section, "citations") do
      citations_str = section["citations"]
        |> Enum.with_index()
        |> Enum.map(fn {cit, index} -> "[#{index}] #{cit}" end)
        |> Enum.join("\n")

      "\n\n#{citations_str}"
    else
      ""
    end

    String.trim("## #{section["section_title"]}\n\n#{section[content_key]}\n\n#{subsections}#{citations}")
  end

  def subsection_as_str(subsection) do
    content_key = if Map.has_key?(subsection, "description") do
      "description"
    else
      "content"
    end

    String.trim("### #{subsection["subsection_title"]}\n\n#{subsection[content_key]}")
  end
end
