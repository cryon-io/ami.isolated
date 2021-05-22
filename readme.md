### isolated

`isolated` provides easy way to containerize ami applications with podman.

*NOTE: This readme explains usage of `isolated` in general. It is recommended to always refer to documentation of application you want to isolate.*

#### Setup
You can configure `isoalted` as any other ami based application through app.hjson. Underlying application specified under `app` within `app.h/json`.

1. Install `ami` if not installed already
    * `wget https://raw.githubusercontent.com/cryon-io/ami/master/install.sh -O /tmp/install.sh && sh /tmp/install.sh`
2. Create directory for your application (it should not be part of user home folder structure, you can use for example `/ami-apps/nice-isolated-app`)
3. Create `app.json` or `app.hjson` with app configuration you like, e.g.:
```hjson
{
    id: "isolated-app"
    type: "isolated"
    configuration: {
        OUTBOUND_ADDR: <ip>
    }
    app: { // Here goes anything you would put in app.h/json of non isolated app
        type: <app type>,
        configuration: {
            <app configuration>
        }
    }
    user: <username>
}
```
You can isolate any ami based application

4. Run `ami --path=<your app path> setup`
   * e.g. `ami --path=/mns/etho1`
. Run `ami --path=<your app path> --help` to investigate available commands
5. Start your node with `ami --path=<your app path> start`
6. Check info about the node `ami --path=<your app path> info`

##### Configuring isolated environment
Isolated environment is by default systemd running withing podman container. You can adjust it by passing parameters of `podman run`.
You can pass these by specifying `STARTUP_ARGS` under configuration as follows:
```hjson
{
    ...
    type: "isolated"
    configuration: {
        STARTUP_ARGS: {
            "--rm",
            "--cgroupns=<mode>",
            ...
        }
    }
    ...
}
```
If you want to bind container directly to specified interface or ip you can use `OUTBOUND_ADDR` option:
```hjson
{
    ...
    type: "isolated"
    configuration: {
        OUTBOUND_ADDR: "<ipv4 or interface name>"
    }
    ...
}
```

##### Configuration change: 
1. `ami --path=<your app path> stop`
2. change app.json or app.hjson as you like
3. `ami --path=<your app path> setup --configure`
4. `ami --path=<your app path> start`

*NOTE: `--configure`  reconfigures `isolated` reruns whole setup of isolated application.*

##### Pass commands to isolated application
All commands except `setup`, `remove`, `info`, `start`, `stop `are automatically proxied to isolated application. 
You can always use `pass` command of `isolated` interface to pass these commands directly. 
E.g. to stop isolated app but keep isolated environment running you can run:
```sh
ami pass stop
```

##### Remove app: 
1. `ami --path=<your app path> stop`
2. `ami --path=<your app path> remove --all`

*NOTE: If you want to run remove of only isolated application to rerun clean setup. You can use `pass remove --all`.*

##### Reset app:
1. `ami --path=<your app path> stop`
2. `ami --path=<your app path> remove` - removes app data only
3. `ami --path=<your app path> start`

#### Troubleshooting 

Run ami with `-ll=trace` to enable trace level printout, e.g.:
`ami --path=/mns/etho1 -ll=trace setup`

#### Container and image removal
It is possible to prune podman containers and images with ami with command `ami podman-system-prune` if you use `isolated`

```sh
ami podman-system-prune
```