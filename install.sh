#!/bin/bash
# Author: Jrohy
# github: https://github.com/Jrohy/trojan

#定义操作变量, 0为否, 1为是
HELP=0

REMOVE=0

UPDATE=0

DOWNLAOD_URL="https://github.com/Jrohy/trojan/releases/download/"

VERSION_CHECK="https://api.github.com/repos/Jrohy/trojan/releases/latest"

SERVICE_URL="https://raw.githubusercontent.com/Jrohy/trojan/master/asset/trojan-web.service"

[[ -e /var/lib/trojan-manager ]] && UPDATE=1

#Centos 临时取消别名
[[ -f /etc/redhat-release && -z $(echo $SHELL|grep zsh) ]] && unalias -a

[[ -z $(echo $SHELL|grep zsh) ]] && SHELL_WAY="bash" || SHELL_WAY="zsh"

#######color code########
RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="36m"
FUCHSIA="35m"

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

#######get params#########
while [[ $# > 0 ]];do
    KEY="$1"
    case $KEY in
        --remove)
        REMOVE=1
        ;;
        -h|--help)
        HELP=1
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done
#############################

help(){
    echo "bash $0 [-h|--help] [--remove]"
    echo "  -h, --help           Show help"
    echo "      --remove         remove trojan"
    return 0
}

removeTrojan() {
    #移除trojan
    rm -rf /usr/bin/trojan >/dev/null 2>&1
    rm -rf /usr/local/etc/trojan >/dev/null 2>&1
    rm -f /etc/systemd/system/trojan.service >/dev/null 2>&1

    #移除trojan管理程序
    rm -f /usr/local/bin/trojan >/dev/null 2>&1
    rm -rf /var/lib/trojan-manager >/dev/null 2>&1
    rm -f /etc/systemd/system/trojan-web.service >/dev/null 2>&1

    systemctl daemon-reload

    #移除trojan的专用mysql
    docker rm -f trojan-mysql
    rm -rf /home/mysql >/dev/null 2>&1
    
    #移除环境变量
    sed -i '/trojan/d' ~/.${SHELL_WAY}rc
    source ~/.${SHELL_WAY}rc

    colorEcho ${GREEN} "uninstall success!"
}

checkSys() {
    #检查是否为Root
    [ $(id -u) != "0" ] && { colorEcho ${RED} "Error: You must be root to run this script"; exit 1; }
    if [[ $(uname -m 2> /dev/null) != x86_64 ]]; then
        colorEcho $YELLOW "Please run this script on x86_64 machine."
        exit 1
    fi

    if [[ `command -v apt-get` ]];then
        PACKAGE_MANAGER='apt-get'
    elif [[ `command -v dnf` ]];then
        PACKAGE_MANAGER='dnf'
    elif [[ `command -v yum` ]];then
        PACKAGE_MANAGER='yum'
    else
        colorEcho $RED "Not support OS!"
        exit 1
    fi
}

#安装依赖
installDependent(){
    if [[ ${PACKAGE_MANAGER} == 'dnf' || ${PACKAGE_MANAGER} == 'yum' ]];then
        ${PACKAGE_MANAGER} install socat bash-completion -y
    else
        ${PACKAGE_MANAGER} update
        ${PACKAGE_MANAGER} install socat bash-completion -y
    fi
}

installTrojan(){
    local SHOW_TIP=0
    LASTEST_VERSION=$(curl -H 'Cache-Control: no-cache' -s "$VERSION_CHECK" | grep 'tag_name' | cut -d\" -f4)
    curl -L "$DOWNLAOD_URL/$LASTEST_VERSION/trojan" -o /usr/local/bin/trojan
    chmod +x /usr/local/bin/trojan
    if [[ ! -e /etc/systemd/system/trojan-web.service ]];then
        SHOW_TIP=1
        curl -L $SERVICE_URL -o /etc/systemd/system/trojan-web.service
        systemctl daemon-reload
        systemctl enable trojan-web
    fi
    systemctl restart trojan-web
    #命令补全环境变量
    [[ -z $(grep trojan ~/.${SHELL_WAY}rc) ]] && echo "source <(trojan completion ${SHELL_WAY})" >> ~/.${SHELL_WAY}rc
    source ~/.${SHELL_WAY}rc
    if [[ $UPDATE == 0 ]];then
        colorEcho $GREEN "安装trojan管理程序成功!\n"
        echo "运行命令`colorEcho $BLUE trojan`可进行trojan管理, 浏览器访问'http://域名'可在线trojan多用户管理\n"
        trojan
    else
        colorEcho $GREEN "更新trojan管理程序成功!\n"
    fi
    [[ $SHOW_TIP == 1 ]] && echo "浏览器访问'`colorEcho $BLUE http://域名`'可在线trojan多用户管理"
}

main(){
    [[ ${HELP} == 1 ]] && help && return
    [[ ${REMOVE} == 1 ]] && removeTrojan && return
    [[ $UPDATE == 0 ]] && echo "正在安装trojan管理程序.." || echo "正在更新trojan管理程序.."
    checkSys
    [[ $UPDATE == 0 ]] && installDependent
    installTrojan
}

main