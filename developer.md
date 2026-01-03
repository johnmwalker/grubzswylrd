We decided to go with G++ in VS Code

0. Have VS Code
1. https://www.msys2.org/ -- download the exe (msys2-x86_64-20240507.exe as of writing this)
  - John installed it to N:\Programs\msys2
  - John let the prompt open after installation and pasted in `pacman -S mingw-w64-ucrt-x86_64-gcc`
  - `gcc --version` gives `13.2.0`
  - I guess we run `pacman -Suy` if we want to update
  - Ope but then the VS Code instructions said to do `pacman -S --needed base-devel mingw-w64-ucrt-x86_64-toolchain`
    - It didn't say to do this when John installed on his laptop 2 years later, but John ran it anyway to get gdb and stuff cuz it seemed like it wasn't working otherwise.
  - John added N:\Programs\msys64\ucrt64\bin to the User PATH
  - John ran `gcc --version; g++ --version; gdb --version` and it failed in a normal Powershell window, but it worked in the MingW/Msys terminal, henceforth known as McGribb.
  - John realized he probably needs to sign out and sign back in for the PATH change to take effect
  - 2 years later john realized that there's a lot more to this msys stuff and they may not all have the same PATH config so idk what's up with each one, probably not gonna use the msys windows
  

  K But what about using CUDA in WSL?

  make sure you have latest Nvidia Driver
  wsl --install
  reboot
  wsl --install again, should auto install Ubuntu 24 or whatever is latest
  Set up your username and password

  sudo apt update
  sudo apt upgrade

  sudo apt install -y build-essential

  got cuda toolkit from here: https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=WSL-Ubuntu&target_version=2.0&target_type=deb_network

