#!/usr/bin/env ruby

require 'yajl'

class Event
  attr_reader :sender, :timestamp, :type, :data
  def initialize hash
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
      abort "wtf? found unknown message type #{hash[:event_type]}, exiting"
    end
    case @type
    when :msg
      @data = hash[:chat_message][:message_content][:segment]
    when :topic_change
      @data = hash[:conversation_rename]
    when :join, :part
      @data = hash[:membership_change][:participant_id]
    when :call
      @data = hash[:hangout_event]
    end
    @sender    = hash[:sender_id]
    @timestamp = hash[:timestamp].to_i / 1000000
  end
end
