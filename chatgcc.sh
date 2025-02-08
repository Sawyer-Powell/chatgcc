#!/bin/bash

# Detect OS and architecture
OS_TYPE=$(uname -s)
ARCH_TYPE=$(uname -m)

# Template for the prompt with placeholders
TEMPLATE="You are a C compiler targeting {ARCH} assembly for {OS}. Generate assembly code with the following specifications:
- Make sure you include the main entry symbol for C interop
- Use {SYNTAX} syntax ({SYNTAX_DESC})
- Include necessary sections (.text, .data, etc.)
- Include proper function prologue/epilogue following {ABI} ABI
- Handle C standard library functions appropriately
- If syscalls are needed, use {SYSCALL_MECHANISM} for syscalls
- If you are using a 'call' command, ensure you include the necessary references to the syscall you are making
- Your output will be extracted from a code block formatted as \`\`\`assembly ... \`\`\`
- This output will be assembled using 'as' and linked using 'gcc'
— ensure it compiles without additional modifications"

# Default values (fallback for unknown systems)
ARCH="an unknown architecture"
OS="an unknown OS"
SYNTAX="ATT/GAS"
SYNTAX_DESC="default GNU assembler syntax"
ABI="a generic"
SYSCALL_MECHANISM="a platform-specific method (try your best!)"

# Define settings for known architectures
if [[ "$OS_TYPE" == "Linux" && "$ARCH_TYPE" == "x86_64" ]]; then
    ARCH="x86_64"
    OS="Linux"
    ABI="the Linux x86_64"
    SYSCALL_MECHANISM="the syscall instruction"

elif [[ "$OS_TYPE" == "Linux" && "$ARCH_TYPE" == "aarch64" ]]; then
    ARCH="ARM64 (AArch64)"
    OS="Linux"
    ABI="the Linux ARM64"
    SYSCALL_MECHANISM="svc #0"

elif [[ "$OS_TYPE" == "Darwin" && "$ARCH_TYPE" == "x86_64" ]]; then
    ARCH="x86_64"
    OS="macOS"
    ABI="the macOS x86_64"
    SYSCALL_MECHANISM="syscall (instead of int 0x80)"

elif [[ "$OS_TYPE" == "Darwin" && "$ARCH_TYPE" == "arm64" ]]; then
    ARCH="ARM64 (AArch64)"
    OS="macOS"
    ABI="the macOS ARM64"
    SYSCALL_MECHANISM="svc #0"

else
    # Unknown platform - provide encouragement
    TEMPLATE="Okay, I'm not sure what platform you're on, but let's give it a shot anyway. Here’s what I know:
- OS: $OS_TYPE
- Arch: $ARCH_TYPE

You're a C compiler, and compilers improvise, adapt, and overcome.  
Generate assembly code with these general rules:
- Include an _start entry symbol.
- Use {SYNTAX} syntax ({SYNTAX_DESC}).
- Use the right calling conventions (good luck).
- Include necessary sections (.text, .data, etc.).
- Add function prologue/epilogue (if applicable).
- Handle C standard library calls correctly (or do your best).
- If syscalls are needed, use {SYSCALL_MECHANISM}.
- If you are using a 'call' command, ensure you include the necessary references to the syscall you are making.
- Your output will be extracted from a code block formatted as \`\`\`assembly ... \`\`\`
- This output will be assembled using 'as' and linked using 'gcc'
— ensure it compiles without additional modifications.

I have no clue if this will work. But you got this. 🚀"
fi

# Replace placeholders in the template using `|` as a delimiter
prompt=$(echo "$TEMPLATE" | sed -e "s|{ARCH}|$ARCH|g" | sed -e "s|{OS}|$OS|g" | sed -e "s|{SYNTAX}|$SYNTAX|g" | sed -e "s|{SYNTAX_DESC}|$SYNTAX_DESC|g" | sed -e "s|{ABI}|$ABI|g" | sed -e "s|{SYSCALL_MECHANISM}|$SYSCALL_MECHANISM|g")

echo $prompt

# Use the determined prompt
model="gpt-4o"

# Lots of annoying details to interface with OpenAI API

verbose=false

echo -ne "\rcontacting openai...   \b\b\b"

if [ "$OPENAI_API_KEY" == "" ]; then
	echo -ne "\rOPENAI_API_KEY is not set   \b\b\b\n"
	exit 1
fi

if [ -z "$1" ]; then
	echo "Usage: $0 <c program>"
	exit 1
fi

if [ "$2" == "-v" ]; then
	verbose=true
fi

escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')
json_payload="{\"name\":\"C Compiler\",\"instructions\":\"$escaped_prompt\", \"model\":\"$model\"}"

if [ "$verbose" = true ]; then
	echo "Setting up assistant"
fi

assistant_id=$(curl "https://api.openai.com/v1/assistants" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "OpenAI-Beta: assistants=v2" \
	-s \
	-d "$json_payload" | grep -o '"id": "[^"]*' | cut -d'"' -f4)

if [ "$verbose" = true ]; then
	echo "$assistant_id"
fi

if [ "$verbose" = true ]; then
	echo "Setting up thread"
fi

thread_id=$(curl https://api.openai.com/v1/threads \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "OpenAI-Beta: assistants=v2" \
	-s \
	-d '' | grep -o '"id": "[^"]*' | cut -d'"' -f4)

if [ "$verbose" = true ]; then
	echo "$thread_id"
fi

escaped_content=$(cat "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')

json_payload="{\"role\":\"user\",\"content\":\"$escaped_content\"}"

if [ "$verbose" = true ]; then
	echo "Setting up message chain"
fi

_=$(curl "https://api.openai.com/v1/threads/$thread_id/messages" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "OpenAI-Beta: assistants=v2" \
	-s \
	-d "$json_payload")

if [ "$verbose" = true ]; then
	echo "Setting up run"
fi

escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g' | sed 's/\t/\\t/g')
json_payload="{\"assistant_id\":\"$assistant_id\",\"instructions\":\"$escaped_prompt\"}"

run_id=$(curl https://api.openai.com/v1/threads/$thread_id/runs \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-H "Content-Type: application/json" \
	-H "OpenAI-Beta: assistants=v2" \
	-s \
	-d "$json_payload" | grep -o '"id": "[^"]*' | cut -d'"' -f4)

status="queued"

if [ "$verbose" = true ]; then
	echo "Polling generation status..."
fi

dots=("." ".." "...")
i=0
while [[ "$status" == "queued" || "$status" == "in_progress" ]]; do
	echo -ne "\rgenerating assembly${dots[$((i % 3))]}   \b\b\b"

	status=$(curl https://api.openai.com/v1/threads/$thread_id/runs/$run_id \
		-H "Authorization: Bearer $OPENAI_API_KEY"\
		-s \
		-H "OpenAI-Beta: assistants=v2" | grep -o '"status": "[^"]*' | cut -d'"' -f4)

	i=$((i + 1))
done

if [ verbose == true ]; then
	echo "Retrieving response"
fi

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
gcc -o "${filename%.c}" "${filename%.c}.o"
