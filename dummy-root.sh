#!/bin/sh
current_dir=$(pwd)
if_inside(){
    if  [ -f /run/.containerenv ] ; then
        entrypoint_start
    else
        if_exists
    fi
}
if_exists(){
podman container exists instant-root
    if [ $? != 0 ]  ; then
        generate_dummy_image
    else
        podman_entry_command
    fi
}
generate_dummy_image(){
    for i in $(find / -maxdepth 1 -type d | sed -e "1d" -e "s/\///g") ; do
        mkdir -p $current_dir/dummyroot/$i
    done
    cp $current_dir/dummy-root.sh $current_dir/dummyroot/dummy-root.sh
    chmod 777 $current_dir/dummyroot/dummy-root.sh
    touch $current_dir/dummyroot/run/.containerenv
    tar -cf $current_dir/dummyroot.tar -C $current_dir/dummyroot/ . &&
    podman import $current_dir/dummyroot.tar --message tag dummyroot &&
    podman_create_command
}
podman_create_command(){
podman_command="podman create --hostname \"instant-root\"
		--ipc host
        --cap-add=ALL
		--name \"instant-root\"
		--network host
		--privileged
		--security-opt label=disable
		--user root:root
		--pid host
        --ulimit host 
        --annotation run.oci.keep_original_groups=1
        --userns keep-id"
    for i in $(find / -maxdepth 1 | sed -e "1d" -e "s/\///g" | grep -Ev "dev|proc|sys|run|tmp") ; do
        list_volumes_ro="${list_volumes_ro} --volume /${i}:/${i}:rslave"
    done
    for i in "/dev" "/sys" "/tmp" $HOME; do
        list_volumes="${list_volumes} --volume ${i}:${i}:rslave"
    done
    list_volumes="${list_volumes} --volume /run/user/$(id -u):/run/user/$(id -u):rslave"
    list_volumes="${list_volumes} --mount type=devpts,destination=/dev/pts"
    list_volumes="${list_volumes} --volume /var/log/journal"
podman_command="${podman_command} ${list_volumes_ro} ${list_volumes} -it --env SHELL="$SHELL" --entrypoint '/dummy-root.sh' dummyroot"
cmd="$podman_command"
podman_exec_command
}
podman_exec_command(){
eval ${cmd}
}
podman_entry_command(){
    printf "                exportando variáveis de usuário...       \n"
        while read -r env_list; do
            list_vars="${list_vars} --env \"${env_list}\""
        done < <(printenv)
}
entrypoint_start(){
operation_dir="$HOME/.cache/dummy-root"
mkdir -p $operation_dir &&
    for i in $(find / -maxdepth 1 | sed -e "1d" -e "s/\///g" | grep -Ev "dev|proc|sys|run|tmp|home") ; do
          mkdir -p $operation_dir/overlay/work-$i
          mkdir -p $operation_dir/overlay/upper-$i
          chown -R root:root $operation_dir/overlay/upper-$i
          chown -R root:root $operation_dir/overlay/work-$i
          mount  -t overlay overlay -o lowerdir=/$i,upperdir=$operation_dir/overlay/upper-$i,workdir=$operation_dir/overlay/work-$i /$i
        done
        chown -R root:root /var
        exec $SHELL
}
if_inside
