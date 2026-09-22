SELECT msg_id, LENGTH(content) - LENGTH(replace(content,' ','')) +1 
FROm chat_msgs
