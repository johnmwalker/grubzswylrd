We decided to go with G++ in VS Code

0. Have VS Code
1. https://www.msys2.org/ -- download the exe (msys2-x86_64-20240507.exe as of writing this)
  - John installed it to N:\Programs\msys2
  - John let the prompt open after installation and pasted in `pacman -S mingw-w64-ucrt-x86_64-gcc`
  - `gcc --version` gives `13.2.0`
  - I guess we run `pacman -Suy` if we want to update
  - Ope but then the VS Code instructions said to do `pacman -S --needed base-devel mingw-w64-ucrt-x86_64-toolchain`
  - John added N:\Programs\msys64\ucrt64\bin to the User PATH
  - John ran `gcc --version; g++ --version; gdb --version` and it failed in a normal Powershell window, but it worked in the MingW/Msys terminal, henceforth known as McGribb.
  - John realized he probably needs to sign out and sign back in for the PATH change to take effect