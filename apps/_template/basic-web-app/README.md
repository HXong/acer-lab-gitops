# Basic Web App Template

Use this as a starting point when adding a new simple HTTP app to `acer-lab-gitops`.

Copy this folder:

```bash
cp -r apps/_template/basic-web-app apps/<new-app-name>
```

Then replace:

- `app-name`
- `app-namespace`
- `ghcr.io/hxong/app-name:latest`
- `nodePort: 30090`

Notes:

- Use a unique namespace per app where possible.
- Use a unique NodePort in the 30000-32767 range.
- Add imagePullSecrets if the image is private on GHCR.
- Add readiness/liveness probes for HTTP apps.
- Add resource requests and limits.
