# Debug

Image used for debugging purposes.

To connect to a debug instance you run kubectl debug like this:
```sh
 kubectl debug -it <podName> --image="europe-north1-docker.pkg.dev/nais-io/nais/images/debug:latest" --profile=restricted
 ```

The debug container will exist in the pod until the pod restarts.

## Java diagnostics

Use `--target=<application-container>` to share the application's PID namespace.
The image uses UID/GID `1069:1069`, matching the Nais application defaults, so
`jcmd` and `jmap` can attach without mounting the application's `/tmp`.
If the application overrides its user or group, set matching `runAsUser` and
`runAsGroup` values using `kubectl debug --custom`.
