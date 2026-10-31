#!/usr/bin/env ruby
# Usage: script/render_ai_log.rb <cursor-transcript.jsonl> > transcript.md
require "json"

def fence(text, lang = "")
  ticks = text.scan(/`{3,}/).map(&:size).max.to_i
  ticks = ticks >= 3 ? ticks + 1 : 3
  "#{'`' * ticks}#{lang}\n#{text}\n#{'`' * ticks}"
end

def quote(text)
  text.lines.map { |line| line.strip.empty? ? ">" : "> #{line.chomp}" }.join("\n")
end

def user_text(text)
  query = text[%r{<user_query>(.*?)</user_query>}m, 1]
  attachments = text.scan(/^- (\S+\.\w+)$/).flatten.map { |path| "_Attached: #{File.basename(path)}_" }
  [ *attachments, (query || text).strip ].join("\n\n")
end

def tool_summary(name, input)
  detail = input["description"] || input["command"] || input["path"] || input["name"] || input["toolName"]
  detail ? "#{name}: #{detail.to_s.lines.first.to_s.strip[0, 120]}" : name
end

turn = 0
puts "# Cursor agent transcript\n\n"
puts "Rendered verbatim from the raw JSONL export. User prompts are block-quoted; tool calls are collapsed.\n\n"

File.foreach(ARGV.fetch(0)) do |line|
  entry = JSON.parse(line)

  if entry["type"] == "turn_ended"
    puts "\n_Turn ended: #{[ entry['status'], entry['error'] ].compact.join(' - ')}_\n\n---"
    next
  end

  entry.dig("message", "content").each do |part|
    case [ entry["role"], part["type"] ]
    when %w[user text]
      turn += 1
      puts "\n## User prompt #{turn}\n\n#{quote(user_text(part['text']))}\n"
    when %w[assistant text]
      puts "\n**Assistant:**\n\n#{part['text'].strip}\n"
    when %w[assistant tool_use]
      input = part["input"]
      body = input["plan"] ? "#{input['plan']}\n\n#{fence(JSON.pretty_generate(input.reject { |k, _| k == 'plan' }), 'json')}" : fence(JSON.pretty_generate(input), "json")
      puts "\n<details><summary>Tool call - #{tool_summary(part['name'], input).gsub('<', '&lt;')}</summary>\n\n#{body}\n\n</details>\n"
    end
  end
end
