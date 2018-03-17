# ombi-deb-build
Script to build Debian packages for Ombi

# Install dependencies 
```
$ sudo apt update && sudo apt upgrade
$ sudo apt install -y jq dpkg-dev dh-make dh-systemd binutils-arm-linux-gnueabihf
```
Then just `./build.sh`!

# Custom script
If a .deb was built, the script calls `./custom.sh ${branch} ${latestVersion}`.  
This means you can call a custom script which deploys your debian package to a repo.

# Output directories
.deb files go here after being built, depending on branch and arch: `${branch}/${arch}/builds/`

**For example:**  
master/amd64/builds/  
master/armhf/builds/  
develop/amd64/builds/  
develop/armhf/builds/  
