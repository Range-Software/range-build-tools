#!/bin/bash

if [ -z "$_BUILD_LOG_FNAME" ]
then
    _BUILD_LOG_FNAME=""
fi

if [ -z "$_DEBUG_LOG_FNAME" ]
then
    _DEBUG_LOG_FNAME=""
fi

if [ -z "$_ECHO_INTEND" ]
then
    _ECHO_INTEND=$[0]
fi

set_indent()
{
    _ECHO_INTEND=$[_ECHO_INTEND+1]
}

set_unindent()
{
    _ECHO_INTEND=$[_ECHO_INTEND-1]
    if [ $_ECHO_INTEND -lt 0 ]
    then
        _ECHO_INTEND=$[0]
    fi
}

get_indent()
{
    echo $_ECHO_INTEND
}

get_indent_text()
{
    local _intMessage=""
    local _int="$[0]"
    while [ "$_int" -lt "$_ECHO_INTEND" ]
    do
        _intMessage+=" > "
        _int=$[_int+1]
    done
    echo "$_intMessage"
}

get_log_time()
{
    echo "$(date +%d-%b-%Y) $(date +%T)"
}

echo_stack()
{
    local _nIgnore=0
    if [ ! -z "$1" ]
    then
        _nIgnore="$1"
    fi

    local i=$[0]
    local n=$[0]
    while [ ! -z "${FUNCNAME[$i]}" ]
    do
        if [ $i -ge $_nIgnore ]
        then
            local _currLineNo=0
            if [ $i -eq 0 ];then
                _currLineNo=$LINENO
            else
                _currLineNo=${BASH_LINENO[$i-1]}
            fi
            echo "  $n -> ${BASH_SOURCE[$i]}:$_currLineNo:${FUNCNAME[$i]}"
            n=$[n+1]
        fi
        i=$[i+1]
    done
}

echo_f()
{
    if [ $# -gt 1 ]
    then
        local _logFile="$1"
        local _logDir=$(dirname "$_logFile")
        if [ -d "$_logDir" ]
        then
            shift
            echo "$@" >> "$_logFile"
        fi
    fi
}

echo_i()
{
    local _message="-I-|$(get_log_time)|$(get_indent_text)""$@"
    echo "$_message" >&1
    if [ ! -z "$_BUILD_LOG_FNAME" ]
    then
        # log into the build log
        echo_f "$_BUILD_LOG_FNAME" "$_message"
    fi
    if [ -n "${_DEBUG_LOG_FNAME}" ]
    then
        # log into the debug log
        _message+=" (called from $(basename ${BASH_SOURCE[1]})(${BASH_LINENO[0]}):${FUNCNAME[1]})"
        echo_f "${_DEBUG_LOG_FNAME}" "$_message"
    fi
}

echo_w()
{
    local _message="-W-|$(get_log_time)|$(get_indent_text)""$@"
    echo "$_message" >&2
    if [ ! -z "$_BUILD_LOG_FNAME" ]
    then
        # log into the build log
        echo_f $_BUILD_LOG_FNAME "$_message"
    fi
    if [ -n "${_DEBUG_LOG_FNAME}" ]
    then
        # log into the debug log
        _message+=" (called from $(basename ${BASH_SOURCE[1]})(${BASH_LINENO[0]}):${FUNCNAME[1]})"
        echo_f "${_DEBUG_LOG_FNAME}" "$_message"
    fi
}

echo_e()
{
    local _message="-E-|$(get_log_time)|$(get_indent_text)""$@"
    echo "$_message" >&2
    if [ ! -z "$_BUILD_LOG_FNAME" ]
    then
        # log into the build log
        echo_f $_BUILD_LOG_FNAME "$_message"
    fi
    if [ -n "${_DEBUG_LOG_FNAME}" ]
    then
        # log into the debug log
        _message+=" (called from $(basename ${BASH_SOURCE[1]})(${BASH_LINENO[0]}):${FUNCNAME[1]})"
        echo_f "${_DEBUG_LOG_FNAME}" "$_message"
    fi
}

assert_success()
{
    local _return_value="$1"
    local _error_message="$2"
    local _exit="$3"
    if [ "$_return_value" -ne 0 ]; then
        echo_e "$_error_message"
        if [ "$_exit" = "true" ]; then
            exit 1
        fi
    fi
    return "$_return_value"
}

assert_nonempty()
{
    if [ -z "$1" ]
    then
        echo "Value is empty. $2" >&2
        exit 1
    fi
}

touch_dir()
{
    local _dir="$1"
    local _clean="$2"
    if [ -z "$_dir" ]
    then
        echo_e "Missing directory"
        return 1
    fi
    if [ -d "$_dir" ]
    then
        echo_i "Directory '${_dir}' already exists"
        if [ "$_clean" = true ]
        then
            rm -rfv "$_dir/"*
        fi
        return 0
    fi
    echo_i "Creating directory '${_dir}'"
    mkdir -p "$_dir"
    if [ $? -ne 0 ]
    then
        echo_e "Failed to create a directory '${_dir}'"
        return 1
    fi
    return 0
}

copy_dir_content()
{
    local _srcDir="$1"
    local _dstDir="$2"
    local _recursiveParam=
    if [ "$3" = "true" ]
    then
        _recursiveParam='R'
    fi

    if [ -z "$( ls -A "$_srcDir" )" ]
    then
        return 0
    fi

    cp -v$_recursiveParam "$_srcDir/"* "$_dstDir"
}

extend_path()
{
    local _path="$1"
    local _add_path="$2"
    if [ -z "$_path" ]
    then
        echo "$_add_path"
    else
        echo "$_path:$_add_path"
    fi
}

extract_cmd_parameter_value()
{
    echo "${1#*=}"
}

