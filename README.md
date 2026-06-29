# nginx-bookworm-hardened
patched version of nginx:1.25-bookworm

# Build instructions:
make sure you work on windows OS.
1. make sure you have git, Docker desktop and make installed on your computer.
2. git clone this repository
3. run: ''' make all '''
this command will create the hardened docker image!

# Image size:
I ran
'''
docker image inspect nginx:1.25-bookworm --format='{{.Size}}'
docker image inspect nginx-hardened:latest --format='{{.Size}}'
'''
before:
after:



# Risidual risk assesment:
I was not able to make this image 100% secure at this point. in order to do so:
I will have to patch and bump versions of all the risks we can see in the baseline files.

with more time, I would dig dipper into the CVEs and find the root cause of them. my goal is to make this image as secure as possible.
This mission was fascinating for me, as a DevOps engineer I learned a LOT about images, CVEs, and especially understood how important is the work Echo does.
I as introduced to new technologies, and I can not wait to continue working with them.
Thank you for the opportunity!
