rpm -qilp techmago-settings-1.0.0-1.noarch.rpm


Para subir pro repo:
```
  file=*.rpm
  curl -v --user 'user:pass' --upload-file ${file} https://repo.techsytes.com/repository/centos-8-techsytes/${file}
```
