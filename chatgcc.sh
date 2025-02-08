# Try a custom prompt here

prompt="
You are a C compiler targeting x86_64 assembly. Generate assembly code with the following specifications:
- Make sure you include the _start entry symbol
- Use AT&T/GAS syntax (default GNU assembler syntax)
- Include necessary sections (.text, .data, etc.)
- Include proper function prologue/epilogue
- Handle C standard library functions appropriately
- Include comments explaining key operations
- Target Linux x86_64 platform
- If you are using a 'call' command, ensure you include the necessary references to the syscall you are making
"

model="gpt-4o"

# Lots of annoying details to interface with openai api

if [ -z "$1" ]; then
    echo "Usage: $0 <c program>"
    exit 1
fi


escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')
json_payload="{\"name\":\"C Compiler\",\"instructions\":\"$escaped_prompt\", \"model\":\"$model\"}"

echo "Setting up assistant"

assistant_id=$(curl "https://api.openai.com/v1/assistants" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "OpenAI-Beta: assistants=v2" \
	-s \
	-d "$json_payload" | grep -o '"id": "[^"]*' | cut -d'"' -f4)

echo "$assistant_id"

echo "Setting up thread"

thread_id=$(curl https://api.openai.com/v1/threads \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "OpenAI-Beta: assistants=v2" \
	-s \
	-d '' | grep -o '"id": "[^"]*' | cut -d'"' -f4)

echo "$thread_id"


escaped_content=$(cat "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')

json_payload="{\"role\":\"user\",\"content\":\"$escaped_content\"}"

echo "Setting up message chain"

_=$(curl "https://api.openai.com/v1/threads/$thread_id/messages" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "OpenAI-Beta: assistants=v2" \
    -s \
    -d "$json_payload")

echo "Setting up run"

escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')
json_payload="{\"assistant_id\":\"$assistant_id\",\"instructions\":\"$escaped_prompt\"}"

run_id=$(curl https://api.openai.com/v1/threads/$thread_id/runs \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "Content-Type: application/json" \
	-H "OpenAI-Beta: assistants=v2" \
	-d "$json_payload" | grep -o '"id": "[^"]*' | cut -d'"' -f4)

status="queued"

echo "Polling generation status..."

while [[ "$status" == "queued" || "$status" == "in_progress" ]]; do
	status=$(curl https://api.openai.com/v1/threads/$thread_id/runs/$run_id \
		-H "Authorization: Bearer $OPENAI_API_KEY"\
		-s \
		-H "OpenAI-Beta: assistants=v2" | grep -o '"status": "[^"]*' | cut -d'"' -f4)
	echo "generating..."
done

echo "Retrieving response"

# Trying to compile the response from the AI

assembly=$(curl https://api.openai.com/v1/threads/$thread_id/messages \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-s \
	-H "OpenAI-Beta: assistants=v2" | grep -oP '```assembly\K[^`]*(?=```)' | sed 's/^//')

filename="$1"
echo -e "$assembly" | sed 's/\\"/"/g' > "${filename%.c}.asm"

cat "${filename%.c}.asm"

as -o "${filename%.c}.o" "${filename%.c}.asm" 
ld -o "${filename%.c}" "${filename%.c}.o"
