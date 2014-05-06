hangouts_to_irc.rb
==================

Converts a Hangouts.json file generated with Google Takeout into a human-readable format.

Usage: 
`./parse_chat.rb Hangouts.json`

This will spit out all of your chats named semi-appropriately. It looks awful, but it works well enough for our purposes.

# ALIASES
You can map a `chat_id` to a friendlier name with the aliases.yaml file. It's a simple YAML hash of id to name.

The script should give you a list of mappings of IDs to names after being run on a file. This will be in a prettyprinted Ruby

Hash format, not suitable for being copypasted into aliases.yaml. Sorry about that. I might change that eventually.

# READ ME PLEASE
You have to name the aliases file "aliases.yaml" or it will not work.
