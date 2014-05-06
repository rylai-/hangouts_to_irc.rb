#!/usr/bin/env ruby

require 'yajl'
require 'yaml'
require 'pp'

class Message
  attr_reader :lines
  def initialize hash
    @lines = []
    if hash[:segment]
      hash[:segment].each do |seg|
        @lines << seg[:text]
      end
    end
    if hash[:attachment]
      hash[:attachment].each do |attachment|
        @lines << attachment[:embed_item]['embeds.PlusPhoto.plus_photo'.to_sym][:url]
      end
    end
  end
end
class Event
  attr_reader :sender, :timestamp, :type, :data, :conversation
  def initialize hash, conversation
    case hash[:event_type]
    when 'REGULAR_CHAT_MESSAGE'
      @type = :msg
    when 'ADD_USER';
      @type = :join
    when 'REMOVE_USER'
      @type = :part
    when 'HANGOUT_EVENT'
      @type = :call
    when 'RENAME_CONVERSATION'
      @type = :topic_change
    else
      abort "wtf? found unknown event type #{hash[:event_type]}, exiting"
    end
    case @type
    when :msg
      @data = Message.new hash[:chat_message][:message_content]
    when :topic_change
      @data = hash[:conversation_rename]
    when :join, :part
      @data = hash[:membership_change][:participant_id]
    when :call
      @data = hash[:hangout_event]
    end
    @conversation = conversation
    @sender    = hash[:sender_id]
    @timestamp = hash[:timestamp].to_i / 1000000
  end
  def to_s
    case @type
    when :msg
      @data.lines.map do |line|
        "#{Time.at(@timestamp).strftime('%F %T')} <#{@conversation.get_friendly_name @sender[:chat_id]}> #{line}"
      end.join "\n"
    when :topic_change
      "#{Time.at(@timestamp).strftime('%F %T')} #{@conversation.get_friendly_name @sender[:chat_id]} changed the topic from #{@data[:old_name] || '(none)'} to #{data[:new_name]}"
    when :join
      "#{Time.at(@timestamp).strftime('%F %T')} --> #{@conversation.get_friendly_name @sender[:chat_id]} has joined the chat"
    when :part
      "#{Time.at(@timestamp).strftime('%F %T')} --> #{@conversation.get_friendly_name @sender[:chat_id]} has left the chat"
    when :call
      "#{Time.at(@timestamp).strftime('%F %T')} --> #{@conversation.get_friendly_name @sender[:chat_id]} called the chat"
    end
  end

end
class Conversation
  attr_reader :events, :participants, :id, :me, :pm, :name, :aliases
  attr_accessor :name
  def initialize hash, aliases=nil
    @@suggested_aliases ||= Hash.new {|hsh, key| hsh[key] = [] }
    @aliases = aliases
    @id     = hash[:conversation_id][:id]
    @events = hash[:conversation_state][:event].map { |e| Event.new e, self }.sort_by { |e| e.timestamp }
    @participants = hash[:conversation_state][:conversation][:participant_data]
    @me     = hash[:conversation_state][:conversation][:self_conversation_state][:self_read_state][:participant_id]
    case hash[:conversation_state][:conversation][:type]
    when 'STICKY_ONE_TO_ONE'
      @pm = true
      @name = get_friendly_name (hash[:conversation_state][:conversation][:current_participant] - [@me]).first[:chat_id]
    when 'GROUP'
      @pm = false
      @name = hash[:conversation_state][:conversation][:name]
    end
  end
  def get_friendly_name chat_id
    if @aliases && @aliases[chat_id.to_i]
      return @aliases[chat_id.to_i]
    end
    participant = @participants.find { |p| p[:id][:chat_id] == chat_id.to_s }
    unless participant.nil?
      if participant[:fallback_name] && !@@suggested_aliases[chat_id].include?(participant[:fallback_name])
        @@suggested_aliases[chat_id] << participant[:fallback_name]
      end
      participant[:fallback_name] || chat_id
    else
      "unknown"
    end
  end
  def write_to_file file_handle
    @events.each do |event|
      file_handle.puts event.to_s
    end
  end
  def suggested_aliases
    @@suggested_aliases
  end
end

def write_conversation_to_file conversation
  @unknown_count ||= 0
  if conversation.name.nil?
    filename = "unknown_#{@unknown_count}.log"
    @unknown_count += 1
  else
    filename = "#{conversation.name}.log"
  end

  File.open(filename, 'w') do |f|
    conversation.events.each do |event|
      f.puts event.to_s
    end
  end
end


abort "incorrect amount of arguments: usage is #{$0} Hangouts.json" unless ARGV.length == 1

parser = Yajl::Parser.new(:symbolize_keys => true)
file = File.open(ARGV.first)
aliases = {}
if File.exists?('aliases.yaml')
  aliases = YAML.load_file('aliases.yaml')
end
conversations = parser.parse(file)[:conversation_state].map { |c| Conversation.new c, aliases }
conversations.each do |conversation|
  puts "writing #{conversation.name} to file..."
  write_conversation_to_file conversation
end
unless conversations.last.suggested_aliases.empty?
  puts "I recommend that you add some of the following to your aliases.yaml file and run me again:"
  pp conversations.last.suggested_aliases
end
