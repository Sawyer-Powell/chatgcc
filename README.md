# chatgcc

A cursed C compiler. A joke/art project, dear god don't use this in production.

## Usage
```sh
export OPENAI_API_KEY="sk-..."
chmod +x chatgcc
./chatgcc test.c
``````

`chatgcc` will ask ChatGPT to generate either x86_64 or ARM64 assembly based on your platform. 
It will also ask ChatGPT to make the assembly platform compatible if you are using a Linux or Mac computer
(thanks to some greate contributions by HenkPoley).

`chatgcc` will then try to assemble the output from ChatGPT using `as`, and link using `gcc`.

## Modifying

The top of `chatgcc` includes a number of variables you can tune, including the prompt sent to OpenAI, and the model.

## Available work

Currently, this "compiler" can only link to the C standard library. It's likely we can get ChatGPT to also
generate the linking flags for `gcc` to build the executable.
