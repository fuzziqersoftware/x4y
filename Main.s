.intel_syntax noprefix


# some general notes:
# we don't strictly follow the system v abi in this file. all functions take
# arguments in the usual order (rdi, rsi, rdx, rcx, ...) but some functions
# return values in the same order instead of using rax and rdx. the argument
# and return registers for each function are defined in the comments.


.globl _strlen_newline
_strlen_newline:
  # params: rdi = string
  # returns: rdi = length
  mov rax, rdi

_strlen_newline__again:
  cmp byte ptr [rdi], 0x0A
  jz _strlen_newline__done
  inc rdi
  jmp _strlen_newline__again

_strlen_newline__done:
  sub rdi, rax
  ret


_strcpy_newline:
  # params: rdi = target string, rsi = source string
  # returns: rdi = ptr past end of bytes written to target

_strcpy_newline__again:
  mov cl, [rsi]
  cmp cl, 0x0A
  jz _strcpy_newline__done
  mov [rdi], cl
  inc rdi
  inc rsi
  jmp _strcpy_newline__again

_strcpy_newline__done:
  ret


_read_file:
  # params: rdi = filename
  # returns: rdi = data pointer, rsi = size in bytes
  # stack: rsp -> fd, stat struct (overwritten by the below)
  # stack: rsp -> fd, size, data ptr
  # note that this function's stack is intentionally misaligned; it's supposed
  # to be called misaligned by main()

  sub rsp, 0x100  # I don't actually know how big the stat struct is, lolz

  # open the file
  xor rsi, rsi  # O_RDONLY == 0
  call _open
  cmp rax, 0
  jl _error_exit_misaligned
  mov [rsp], rax

  # get the file size
  mov rdi, rax  # fd
  lea rsi, [rsp + 8]  # stat struct ptr
  call _fstat
  cmp rax, 0
  jl _error_exit_misaligned
  mov rdi, [rsp + 0x50]  # size field is here on osx
  mov [rsp + 8], rdi  # size

  # allocate an appropriate buffer
  inc rdi
  call _malloc
  cmp rax, 0
  je _error_exit_misaligned
  mov [rsp + 16], rax  # data ptr

  # read the entire file into memory
  mov rsi, rax  # data ptr
  mov rdi, [rsp]  # fd
  mov rdx, [rsp + 8]  # size
  call _read
  cmp rax, [rsp + 8]
  jne _error_exit_misaligned

  # close the file
  mov rdi, [rsp]
  call _close

  # return the values
  mov rdi, [rsp + 16]  # data ptr
  mov rsi, [rsp + 8]  # size

  add rsp, 0x100
  ret


_choose_file_line:
  # params: rdi = data ptr, rsi = size in bytes, rdx = line number
  # returns: rdi = pointer to rdx'th line in the data (mod total line count)

  # basic idea: scan the contents once to count the line endings, mod the line
  # number by that value, then scan again to find that line

  # later, we'll divide the requested line number by the file's line count. but
  # the line number has to be in rdx:rax because that's how division works
  mov rax, rdx
  xor rdx, rdx

  # 1. scan the contents to count the lines
  xor rcx, rcx  # byte value
  mov r8, rdi  # scan ptr
  lea r9, [rdi + rsi]  # scan end ptr
  xor r10, r10  # line count

_choose_file_line__count_lines__count_next_byte:
  mov cl, [r8]
  cmp cl, 0x0A  # newline
  sete cl
  add r10, rcx
  inc r8
  cmp r8, r9
  jne _choose_file_line__count_lines__count_next_byte

  # 2. mod the line number by the line count in the file
  div r10
  # now rdx is the modded line number we want

  # 3. select the appropriate line in the file

  # just return the pointer if it's the first line
  test rdx, rdx
  jnz _choose_file_line__not_first_line
  ret
_choose_file_line__not_first_line:

  # rdi = scan ptr (we don't need the data ptr at all after this)
  xor rax, rax  # current line number

_choose_file_line__select_line__count_next_byte:
  cmp byte ptr[rdi], 0x0A  # newline
  jne _choose_file_line__select_line__not_newline
  inc rax  # increment current line number; if it matches rdx, we're done
  cmp rax, rdx
  jnz _choose_file_line__select_line__not_chosen_line
  inc rdi  # return ptr to the byte after the newline
  ret

_choose_file_line__select_line__not_chosen_line:
_choose_file_line__select_line__not_newline:
  inc rdi
  jmp _choose_file_line__select_line__count_next_byte


_get_random_data:
  # returns: rdi = random value, rsi = random value, rdx = random value
  # note that this function's stack is intentionally misaligned; it's supposed
  # to be called misaligned by main()
  sub rsp, 32

  mov dword ptr [rsp], 0x7665642F
  mov dword ptr [rsp + 4], 0x6172752F
  mov dword ptr [rsp + 8], 0x6D6F646E
  mov dword ptr [rsp + 12], 0x00000000

  # open /dev/urandom
  mov rdi, rsp
  xor rsi, rsi  # O_RDONLY == 0
  call _open
  cmp rax, 0
  jl _error_exit_misaligned
  mov [rsp], rax

  # read some random data
  mov rdi, rax  # fd
  lea rsi, [rsp + 8]  # buffer
  mov rdx, 24  # size
  call _read
  cmp rax, 24
  jl _error_exit_misaligned

  # close /dev/urandom
  mov rdi, [rsp]
  call _close

  mov rdi, [rsp + 8]
  mov rsi, [rsp + 16]
  mov rdx, [rsp + 24]
  add rsp, 32
  ret


.globl _main
_main:
  # stack vars:
  # rbp + 8: startups-fake contents
  # rbp + 16: startups-fake size
  # rbp + 24: startups-real contents
  # rbp + 32: startups-real size
  # rbp + 40: populations contents
  # rbp + 48: populations size
  # rbp + 56: random1, fake startup name ptr
  # rbp + 64: random2, real startup name ptr
  # rbp + 72: random3, population name ptr
  # rbp + 80: result string length

  sub rsp, 88
  push rbp
  mov rbp, rsp

  # load the startups-fake file
  mov dword ptr [rsp + 56], 0x72617473
  mov dword ptr [rsp + 60], 0x73707574
  mov dword ptr [rsp + 64], 0x6B61662D
  mov dword ptr [rsp + 68], 0x78742E65
  mov dword ptr [rsp + 72], 0x00000074
  lea rdi, [rsp + 56]
  call _read_file
  mov [rbp + 8], rdi
  mov [rbp + 16], rsi

  # load the startups-real file
  mov dword ptr [rsp + 56], 0x72617473
  mov dword ptr [rsp + 60], 0x73707574
  mov dword ptr [rsp + 64], 0x6165722D
  mov dword ptr [rsp + 68], 0x78742E6C
  mov dword ptr [rsp + 72], 0x00000074
  lea rdi, [rsp + 56]
  call _read_file
  mov [rbp + 24], rdi
  mov [rbp + 32], rsi

  # load the populations file
  mov dword ptr [rsp + 56], 0x75706F70
  mov dword ptr [rsp + 60], 0x6974616C
  mov dword ptr [rsp + 64], 0x2E736E6F
  mov dword ptr [rsp + 68], 0x00747874
  lea rdi, [rsp + 56]
  call _read_file
  mov [rbp + 40], rdi
  mov [rbp + 48], rsi

  # get some randomness
  call _get_random_data
  mov [rbp + 56], rdi
  mov [rbp + 64], rsi
  mov [rbp + 72], rdx

  # pick out the target startup name
  mov rdx, rdi
  mov rdi, [rbp + 8]
  mov rsi, [rbp + 16]
  call _choose_file_line
  mov [rbp + 56], rdi

  # pick out the source startup name
  mov rdi, [rbp + 24]
  mov rsi, [rbp + 32]
  mov rdx, [rbp + 64]
  call _choose_file_line
  mov [rbp + 64], rdi

  # pick out the population name
  mov rdi, [rbp + 40]
  mov rsi, [rbp + 48]
  mov rdx, [rbp + 72]
  call _choose_file_line
  mov [rbp + 72], rdi

  # compute the length of the string
  mov qword ptr [rbp + 80], 14  # = 1 + strlen("X: it\'s Y for Z!" without the X, Y, or Z)
  call _strlen_newline
  mov [rbp + 80], rdi
  mov rdi, [rbp + 56]
  call _strlen_newline
  add [rbp + 80], rdi
  mov rdi, [rbp + 64]
  call _strlen_newline
  add rdi, [rbp + 80]

  # round the length up to the next 16-byte boundary
  add rdi, 15
  shr rdi, 4
  shl rdi, 4

  # allocate stack space for the string
  sub rsp, rdi
  push rdi

  # write the string
  lea rdi, [rsp + 8]
  mov rsi, [rbp + 56]
  call _strcpy_newline  # returns ptr past end of added string
  mov byte ptr [rdi], 0x3A  # :
  mov byte ptr [rdi + 1], 0x20  # space
  mov byte ptr [rdi + 2], 0x69  # i
  mov byte ptr [rdi + 3], 0x74  # t
  mov byte ptr [rdi + 4], 0x27  # '
  mov byte ptr [rdi + 5], 0x73  # s
  mov byte ptr [rdi + 6], 0x20  # space
  add rdi, 7
  mov rsi, [rbp + 64]
  call _strcpy_newline
  mov byte ptr [rdi], 0x20  # space
  mov byte ptr [rdi + 1], 0x66  # f
  mov byte ptr [rdi + 2], 0x6F  # o
  mov byte ptr [rdi + 3], 0x72  # r
  mov byte ptr [rdi + 4], 0x20  # space
  add rdi, 5
  mov rsi, [rbp + 72]
  call _strcpy_newline
  mov byte ptr [rdi], 0x21  # !
  mov byte ptr [rdi + 1], 0x00  # \0

  # print the string to stdout
  lea rdi, [rsp + 8]
  call _puts

  # free the string stack space
  pop rdi
  add rsp, rdi

  # return 0
  xor rax, rax
  pop rbp
  add rsp, 88
  ret


_error_exit_misaligned:
  sub rsp, 8
_error_exit:
  mov rdi, 1
  jmp _exit


# rbp + 8  = startups.txt data
# rbp + 16 = startups.txt size
# rbp + 24 = populations.txt data
# rbp + 32 = populations.txt size
# rbp + 40 = random1, target startup name ptr
# rbp + 48 = random2, source startup name ptr
# rbp + 56 = random3, population name ptr
# rbp + 64 = result string length including \0
