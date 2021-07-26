#! /usr/bin/env bash

rootPath='/home/cwj/Desktop/test'
server_address='dev@42.193.145.77'
desPath='/home/dev/des'
check()
{
    local val=$1
    local list=$2
    for tmp in $list ;do
        if [[ $val == $tmp ]];then
            return 1
        fi
    done
    return 0
}

op_func()
{
    check $file "$(ssh $server_address "ls $desPath/$path")"
    if [[ $? == 1 ]];then #当前文件在服务器上
        if  $(test -d $root$path/$file) && $(ssh $server_address "test -d $server_root$path/$file") ;then #当前文件和服务器文件都为目录
            #echo "进入目录[$path/$file]"
            {
                tra_dir $rootPath $desPath $path/$file
            }&
        elif $(test -f $root$path/$file) && $(ssh $server_address "test -f $server_root$path/$file");then ##当前文件和服务器文件都为普通文件
            #echo "当前文件都为普通文件"
            server_key=$(ssh $server_address "sha1sum $server_root$path/$file")
            hash_key=$(sha1sum $root$path/$file)
            pos=$(expr index "$server_key" "/")
            if [[ ${server_key:0:$pos-1} != ${hash_key:0:pos-1} ]]; then #两文件哈希值不相等
                echo "两普通文件哈希值不相等，覆盖上传$path$file"
                ssh $server_address "rm -rf $server_root$path/$file"
                scp $root$path/$file "$server_address:$server_root$path"
                op_func
            #else 
            #    echo "两文件内容一致"
            fi
        else #当前文件和服务器文件属性不一致
            #echo "当前(文件/目录)和服务器（文件/目录）属性不一致，覆盖上传$path$file"
            ssh $server_address "rm -rf $server_root$path/$file"
            scp $root$path/$file "$server_address:$server_root$path"
            op_func
        fi
    else #当前文件不在服务器上
        #echo "当前（文件/目录）不在服务器上"
        if $(test -f $root$path/$file);then
            #echo "上传普通文件$path$file"
            scp $root$path/$file "$server_address:$server_root$path"
            op_func
        else
            #echo "上传目录 $path$file"
            scp -r $root$path/$file "$server_address:$server_root$path"
            op_func
        fi
    fi
}

del_func()
{
    for file in $(ssh $server_address "ls $desPath/$path"); do #删除服务器上有但本地没有的文件
        check $file "$(ls $root$path)"
        if [[ $? == 0 ]];then
            #echo "本地无$file（文件/目录），删除服务器上$file（文件/目录）"
            ssh $server_address "rm -rf $server_root$path/$file"
            del_func
            break
        fi 
    done
}

tra_dir()
{
    local root=$1
    local server_root=$2
    local path=$3
    while [[ ! -s flag.txt ]];do
        sleep 3
        echo "当前操作队列已满，目录[$path]排队等待中...."
    done
    sed -i '1d' flag.txt      
    #echo "同步目录[$path]中..."
    del_func
    for file in $(ls $root$path);do
        op_func
    done
    echo "" >>flag.txt
    wait
}

tra_dir $rootPath $desPath ""
echo "同步成功！！！"
