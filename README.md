# chatgcc

A cursed C compiler

## Usage
```sh
export OPENAI_API_KEY="sk-..."
chmod +x chatgcc
chatgcc test.c

`chatgcc` will ask ChatGPT to generate either x86_64 or ARM64 assembly based on your platform. 
It will also ask ChatGPT to make the assembly platform compatible if you are using a Linux or Mac computer
(thanks to some greate contributions by HenkPoley).

`chatgcc` will then try to assemble the output from ChatGPT using `as`, and link using `gcc`.

## Modifying

The top of `chatgcc.sh` includes a number of variables you can tune, including the prompt sent to OpenAI, and the model.

## Available work

Currently, this "compiler" can only linke to the C standard library. It might be possible to ask ChatGPT to also
generate the linking flags for `gcc` to generate the executable.
