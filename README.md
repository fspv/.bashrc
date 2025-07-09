```sh
cd
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/fspv/.bashrc/refs/heads/master/.local/share/bin/bootstrap.sh)"
.local/share/bin/init-user-env.sh
```

If you want to try my config, run this to spin up the latest version from master

```sh
docker run -it nuhotetotniksvoboden/bashrc:latest
```
