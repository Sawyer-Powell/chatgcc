# chatgcc

A cursed C compiler

## Usage
```sh
export OPENAI_API_KEY="sk-..."
chmod +x chatgcc
chatgcc test.c
```
The program will call OpenAI and save its x86_64 assembly program to `test.asm`. The program will also attempt to assemble that file, and link it.

If assembly and linking succeed, the program should produce an executable: `test`

## Modifying

The top of `chatgcc.sh` includes a number of variables you can tune, including the prompt sent to OpenAI, and the model.
