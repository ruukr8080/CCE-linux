#!

rf="result.json"

# JSON 생성 및 서버 정보 수집
{
    echo "{"
    echo "  \"Server_Info\": {"
    echo "    \"SW_TYPE\": \"$(uname -s)\","
    echo "    \"SW_NM\": \"CentOS\","
    echo "    \"SW_INFO\": \"$(cat /etc/centos-release)\","
    echo "    \"HOST_NM\": \"$(hostname)\","
    echo "    \"DATE\": \"$(date +%y-%m-%d)\","
    echo "    \"TIME\": \"$(date +%H:%M:%S)\","
    echo "    \"IP_ADDRESS\": \"$(ip -4 addr show | grep 'state UP' -A2 | grep 'inet' | head -n1 | awk '{print $2}' | cut -d/ -f1)\","  # 첫 번째 활성 네트워크 인터페이스의 IP 주소
    echo "    \"UNIQ_ID\": \"$(date +%y-%m-%d)_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)\""  # 유니크 ID
    echo "  },"
    echo "  \"Check_Results\": ["
} > "$rf"

# 결과 출력을 위한 공통 함수
print_results() {
    details=("${!1}")
    solutions=("${!2}")

    if [ ${#details[@]} -gt 0 ]; then
        echo "    \"status\":\"[취약]\","
        echo "    \"details\": ["
        for ((i=0; i<${#details[@]}; i++)); do
            if [ $((i + 1)) -lt ${#details[@]} ]; then
                echo "      ${details[$i]},"
            else
                echo "      ${details[$i]}"
            fi
        done
        echo "    ],"
    fi

    if [ ${#solutions[@]} -gt 0 ]; then
        echo "    \"solutions\": ["
        for ((i=0; i<${#solutions[@]}; i++)); do
            if [ $((i + 1)) -lt ${#solutions[@]} ]; then
                echo "      ${solutions[$i]},"
            else
                echo "      ${solutions[$i]}"
            fi
        done
        echo "    ]"
    fi
}

# shellcheck disable=SC2129
U_01() {
    echo "  {"
    echo "    \"Item\": \"U-01\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.1 root 계정 원격 접속 제한\","
    echo "    \"Description\": \"시스템 정책에 root 계정의 원격 터미널 접속 차단 설정이 적용되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/ssh/sshd_config\","

    # shellcheck disable=SC2009
    telnet_running=$(ps -ef | grep telnet | grep -v grep)
    ssh_running=$(ps -ef | grep ssh | grep -v grep)
    
    telnet_service=False
    telnet_file1=False
    telnet_file2=False

    ssh_service=False
    ssh_file1=False

    if [ "$telnet_running" ]; then
        telnet_service=True
        pam_securetty_config=$(cat /etc/pam.d/login | grep -i "pam_securetty.so" | grep -vE '^#|^\s#')
        securetty_config=$(cat /etc/securetty | grep '^ *pts')
        
        if [ -z "$pam_securetty_config" ]; then
            telnet_file1=True
        fi

        if [ "$securetty_config" ]; then
            telnet_file2=True
        fi
    fi

    if [ "$ssh_running" ]; then
        ssh_service=True
        permit_root_login=$(cat /etc/ssh/sshd_config | grep PermitRootLogin | grep -vE '^#|^\s#' | grep no)
        if [ -z "$permit_root_login" ]; then
            ssh_file1=True
        fi
    fi

    declare -a details
    declare -a solutions

    if [ "$telnet_service" == "True" ] || [ "$ssh_service" == "True" ]; then
        :
    else
        echo "    \"status\":\"[양호]\","
        echo "    \"details\": ["
        echo "      \"telnet 및 SSH 서비스가 모두 비활성화되어 있거나, 설정이 적절하게 구성된 상태입니다.\""
        echo "    ]"
    fi

    if [ "$telnet_service" == "True" ]; then
        if [ "$telnet_file1" == "False" ] && [ "$telnet_file2" == "False" ]; then
            echo " {"
            echo "  \"status\":\"[양호]\","
            echo "  \"details\": ["
            echo "  \"telnet 관련 pts/0~pts/x 관련 설정이 존재하지 않으며 \\\"Uth required /lib/security/pam_securetty.so\\\" 설정이 되어 있는 상태입니다.\""
            echo " ]"
            echo " },"

        elif [ "$telnet_file1" == "False" ] && [ "$telnet_file2" == "True" ]; then
            details+=("\"/etc/securetty 파일 내 pts/0~pts/x 관련 설정이 존재하는 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/securetty 파일 내 pts/0~pts/x 관련 설정을 제거하거나 주석 처리해주시기 바랍니다.\"")

        elif [ "$telnet_file1" == "True" ] && [ "$telnet_file2" == "False" ]; then
            details+=("\"/etc/pam.d/login 파일 내 \\\"Uth required /lib/security/pam_securetty.so\\\"이 설정되어 있지 않은 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/pam.d/login 파일 내
            \\\"Uth required /lib/security/pam_securetty.so\\\"를 설정하여 주시기 바랍니다.\"")
        else
            details+=("\"/etc/securetty 및 /etc/pam.d/login 파일 내
            \\\"Uth required /lib/security/pam_securetty.so\\\" 이 설정되어 있지 않은 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/securetty 파일 내 pts/0~pts/x 관련 설정을 제거하거나 주석 처리해주시고
            /etc/pam.d/login 파일 내 \\\"Uth required /lib/security/pam_securetty.so\\\"를 설정하여 주시기 바랍니다.\"")
        fi
    fi



    if [ "$ssh_service" == "True" ]; then
        if [ "$ssh_file1" == "False" ]; then
            details+=("\"ssh 관련 \\\"PermitRootLogin\\\" 설정이 되어 있는 상태입니다.\"")
        else
            details+=("\"SSH 관련 \\\"PermitRootLogin\\\" 설정이 주석 처리되어 root 계정으로 직접 로그인이 가능한 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/ssh/sshd_config 설정 파일 내 \\\"PermitRootLogin\\\" 관련 주석 제거 및 값을 \\\"no\\\"로 설정하여 주시기 바랍니다.\"")
        fi
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_02() {
    echo "  {"
    echo "    \"Item\": \"U-02\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.2 패스워드 복잡성 설정\","
    echo "    \"Description\": \"시스템 정책에 사용자 계정(root 및 일반 계정 모두 해당) 패스워드 복잡성 관련 설정이 되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/pam.d/system-auth\","

    declare -a details
    declare -a solutions
    pam_cracklib_path=$(find / -name 'pam_cracklib.so' -type f -print)

    if [ -n "$pam_cracklib_path" ]; then
        pam_password=$(grep "password" /etc/pam.d/system-auth | grep "pam_cracklib.so")
        if [ -n "$pam_password" ]; then
            minlen_value=$(echo "$pam_password" | awk -F'minlen=' '{print $2}' | awk '{print $1}')
            o_lcredit_value=$(echo "$pam_password" | awk -F'lcredit=' '{print $2}' | awk '{print $1}')
            o_ucredit_value=$(echo "$pam_password" | awk -F'ucredit=' '{print $2}' | awk '{print $1}')
            o_dcredit_value=$(echo "$pam_password" | awk -F'dcredit=' '{print $2}' | awk '{print $1}')
            o_ocredit_value=$(echo "$pam_password" | awk -F'ocredit=' '{print $2}' | awk '{print $1}')

            has_lower=$(awk -v lc="$o_lcredit_value" 'BEGIN { prduplicated_usersint (lc == "" || lc >= 0) ? "false" : "true" }') #영문(소)
            has_upper=$(awk -v uc="$o_ucredit_value" 'BEGIN { print (uc == "" || uc >= 0) ? "false" : "true" }') #영문(대)
            has_digit=$(awk -v dc="$o_dcredit_value" 'BEGIN { print (dc == "" || dc >= 0) ? "false" : "true" }') #숫자
            has_special=$(awk -v oc="$o_ocredit_value" 'BEGIN { print (oc == "" || oc >= 0) ? "false" : "true" }') #특수문자

            lcredit_value=$(echo "$pam_password" | awk -F'lcredit=' '{print $2}' | awk '{gsub("-", ""); print $1}')
            if [ -z "$lcredit_value" ]; then
              o_lcredit_value="-"
            fi
            ucredit_value=$(echo "$pam_password" | awk -F'ucredit=' '{print $2}' | awk '{gsub("-", ""); print $1}')
            if [ -z "$ucredit_value" ]; then
              o_ucredit_value="-"
            fi
            dcredit_value=$(echo "$pam_password" | awk -F'dcredit=' '{print $2}' | awk '{gsub("-", ""); print $1}')
            if [ -z "$dcredit_value" ]; then
              o_dcredit_value="-"
            fi
            ocredit_value=$(echo "$pam_password" | awk -F'ocredit=' '{print $2}' | awk '{gsub("-", ""); print $1}')
            if [ -z "$ocredit_value" ]; then
              o_credit_value="-"
            fi



            if [ -z "$minlen_value" ]; then
                details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수 값이 설정되어 있지 않으며 알파벳 대/소문자, 숫자, 특수문자 등이 설정되어 있지 않은 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 패스워드 복잡성 설정 값(영문·숫자·특수문자를 조합하여 2종류 조합 시 10자리 이상, 3종류 이상 조합 시 8자리 이상의 패스워드)을 회사 내부 규정 및 지침에 맞게 설정하여 주시기 바랍니다.\"")
            else
                if [[ $minlen_value -ge 10 ]]; then #10 이상
                    if [[ $has_lower == "true" && $has_upper == "true" && $has_digit == "true" && $has_special == "true" ]]; then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 알파벳 대문자 최소 $ucredit_value 개, 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "false" && $has_upper == "true" && $has_digit == "true" && $has_special == "true" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 대문자 최소 $ucredit_value 개, 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "true" && $has_upper == "false" && $has_digit == "true" && $has_special == "true" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "false" && $has_upper == "false" && $has_digit == "true" && $has_special == "true" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "true" && $has_upper == "true" && $has_digit == "false" && $has_special == "true" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 알파벳 대문자 최소 $ucredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "true" && $has_upper == "true" && $has_digit == "true" && $has_special == "false" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 알파벳 대문자 최소 $ucredit_value 개, 숫자 최소 $dcredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "true" && $has_upper == "false" && $has_digit == "true" && $has_special == "false" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 숫자 최소 $dcredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "true" && $has_upper == "false" && $has_digit == "false" && $has_special == "true" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "false" && $has_upper == "true" && $has_digit == "true" && $has_special == "false" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 대문자 최소 $ucredit_value 개, 숫자 최소 $dcredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    elif [[ $has_lower == "false" && $has_upper == "true" && $has_digit == "false" && $has_special == "true" ]];then
                        echo "    \"status\":\"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 대문자 최소 $ucredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\""
                        echo "    ]"
                    else
                        details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 복잡성 설정 값으로 최소자리수가 $minlen_value 이며 lcredit: $o_lcredit_value, ucredit: $o_ucredit_value, dcredit: $o_dcredit_value, ocredit: $o_ocredit_value 으로 설정되어 있는 상태입니다.\"")
                        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 영문, 숫자, 특수문자를 조합하여 2종류 이상 조합되도록 /etc/pam.d/system-auth 설정 파일 내 lcredit, ucredit, dcredit, oredit 값을 －1 이하로 설정하여 주시기 바랍니다.\"")
                    fi
                elif [[ $minlen_value -ge 8 ]]; then # 10 미만, 8이상
                    if [[ $has_lower == "true" && $has_upper == "true" && $has_digit == "true" && $has_special == "true" ]]; then
                        details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 알파벳 대문자 최소 $ucredit_value 개, 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\"")
                    elif [[ $has_lower == "false" && $has_upper == "true" && $has_digit == "true" && $has_special == "true" ]];then
                        details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 대문자 최소 $ucredit_value 개, 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\"")
                    elif [[ $has_lower == "true" && $has_upper == "false" && $has_digit == "true" && $has_special == "true" ]];then
                        details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 최소자리수가 $minlen_value 이며 알파벳 소문자 최소 $lcredit_value 개, 숫자 최소 $dcredit_value 개, 특수문자 최소 $ocredit_value 개로 설정되어 있는 상태입니다.\"")
                    else
                        details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 복잡성 설정 값으로 최소자리수가 $minlen_value 이며 lcredit: $o_lcredit_value, ucredit: $o_ucredit_value, dcredit: $o_dcredit_value, ocredit: $o_ocredit_value 으로 설정되어 있는 상태입니다.\"")
                        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 영문, 숫자, 특수문자를 조합하여 3종류 이상 조합되도록 /etc/pam.d/system-auth 설정 파일 내 lcredit, ucredit, dcredit, oredit 값을 －1 이하로 설정하여 주시기 바랍니다.\"")
                    fi
                else
                    details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 복잡성 설정 값으로 최소자리수가 $minlen_value 로 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 최소자리수를 8이상으로 설정하여 주시기 바랍니다.\"")
                fi
            fi
        else
            details+=("\"/etc/pam.d/system-auth 설정 파일 내 패스워드 복잡성 설정 값 (최소자리수, 알파벳 대/소문자 , 숫자, 특수문자) 이 설정되어 있지 않은 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 패스워드 복잡성 설정 값(영문·숫자·특수문자를 조합하여 2종류 조합 시 10자리 이상, 3종류 이상 조합 시 8자리 이상의 패스워드)을 회사 내부 규정 및 지침에 맞게 설정하여 주시기 바랍니다.\"")
        fi
    else
        details+=("\"시스템 내 pam_cracklib.so 모듈이 존재하지 않습니다.\"")
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_03() {
    echo "  {"
    echo "    \"Item\": \"U-03\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.3 계정 잠금 임계값 설정\","
    echo "    \"Description\": \"시스템 정책에 사용자 로그인 실패 임계값이 설정되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/pam.d/system-auth\","

    system_auth_file="/etc/pam.d/system-auth"

    declare -a details
    declare -a solutions

    if [ ! -f "$system_auth_file" ]; then
        details+=("\"시스템에 /etc/pam.d/system-auth 파일이 존재하지 않는 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 패스워드 잠금 임계값을 \\\"5\\\" 이하, 잠금시간을 \\\"3600\\\" 이하로 설정하여 주시기 바랍니다.\"")
    else
        min_fail=$(grep -E '^auth.*required.*pam_faillock.so' "$system_auth_file" | grep -E 'deny=[0-9]+' | grep -oE 'deny=[0-9]+' | cut -d'=' -f2)
        lock_time=$(grep -E '^auth.*required.*pam_faillock.so' "$system_auth_file" | grep -E 'unlock_time=[0-9]+' | grep -oE 'unlock_time=[0-9]+' | cut -d'=' -f2)

        if [ -z "$min_fail" ] || [ -z "$lock_time" ]; then
            details+=("\"/etc/pam.d/system-auth 파일에 계정 잠금 임계값 또는 잠금시간이 설정되어 있지 않습니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 패스워드 잠금 임계값을 \\\"5\\\" 이하, 잠금시간을 \\\"3600\\\" 이하로 설정하여 주시기 바랍니다.\"")
        else
            if [ "$min_fail" -gt 5 ] && [ "$lock_time" -gt 3600 ]; then
                details+=("\"계정 잠금 임계값은 $min_fail, 잠금시간은 $lock_time 인 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 패스워드 잠금 임계값을 \\\"5\\\" 이하, 잠금시간을 \\\"3600\\\" 이하로 설정하여 주시기 바랍니다.\"")
            elif [ "$min_fail" -le 5 ] && [ "$lock_time" -gt 3600 ]; then
                details+=("\"계정 잠금 임계값은 $min_fail, 잠금시간은 $lock_time 인 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 잠금시간을 \\\"3600\\\" 이하로 설정하여 주시기 바랍니다.\"")
            elif [ "$min_fail" -gt 5 ] && [ "$lock_time" -le 3600 ]; then
                details+=("\"계정 잠금 임계값은 $min_fail, 잠금시간은 $lock_time 인 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/pam.d/system-auth 설정 파일 내 패스워드 잠금 임계값을 \\\"5\\\" 이하로 설정하여 주시기 바랍니다.\"")
            else
                echo "    \"status\":\"[양호]\","
                echo "    \"details\": ["
                echo "      \"/etc/pam.d/system-auth 파일에 계정 잠금 임계값이 $min_fail, 잠금시간이 $lock_time 로 설정되어 있는 상태입니다.\""
                echo "    ]"
            fi
        fi
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_04() {
    echo "  {"
    echo "    \"Item\": \"U-04\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.4 패스워드 파일 보호\","
    echo "    \"Description\": \"시스템 사용자 계정(root, 일반계정) 정보가 저장된 파일(예: /etc/passwd, /etc/shadow)에 사용자 계정 패스워드가 암호화되어 저장되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/passwd\","

    declare -a details
    declare -a solutions

    if [ -f /etc/shadow ]; then
        vulnerable_users=$(awk -F: '/bash/ && $2 != "x" {print $1}' /etc/passwd)
        if [ -n "$vulnerable_users" ]; then
            for user in $vulnerable_users; do
				echo -n "$user "
			done
            details+=("\"사용자의 패스워드가 암호화 설정되어 있지 않은 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 모든 사용자의 암호를 암호화 설정하여 주시기 바랍니다.\"")
        else
            echo "    \"status\":\"[양호]\","
            echo "    \"details\": ["
            echo "      \"모든 사용자 계정의 패스워드가 암호화 설정되어 있는 상태입니다.\""
            echo "    ]"
        fi
    else
        details+=("\"/etc/shadow 파일이 존재하지 않는 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/shadow 파일을 생성하시고 모든 사용자의 패스워드를 암호화 설정하여 주시기 바랍니다.\"")
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_44() {
    echo "  {"
    echo "    \"Item\": \"U-44\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.5 root 이외의 UID가 '0' 금지\","
    echo "    \"Description\": \"사용자 계정 정보가 저장된 파일(예: /etc/passwd)에 root(UID=0) 계정과 동일한 UID(User Identification)를 가진 계정이 존재하는지 점검\","
    echo "    \"Command\": \"cat /etc/passwd\","

    declare -a details
    declare -a solutions

    if [ -f /etc/passwd ]; then
        user_with_uid_zero=$(awk -F : '$3==0 && $1!="root" {print $1}' /etc/passwd)
        if [ -z "$user_with_uid_zero" ]; then
            echo "    \"status\":\"[양호]\","
            echo "    \"details\": ["
            echo "      \"root 계정을 제외한 로그인이 가능한 모든 사용자 UID값이 \\\"0\\\"으로 설정되어 있지 않은 상태입니다.\""
            echo "    ]"
        else
            details+=("\"root 계정과 동일한 UID(0)를 갖는 사용자(${user_with_uid_zero[@]})가 존재하는 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 ${user_with_uid_zero[@]} 계정의 UID값을 변경하여 주시기 바랍니다.\"")
        fi
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"


U_45() {
    echo "  {"
    echo "    \"Item\": \"U-45\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.6 root 계정 su 제한\","
    echo "    \"Description\": \"시스템 사용자 계정 그룹 설정 파일(예: /etc/group)에 su 관련 그룹이 존재하는지 점검 및 su 명령어가 su 관련 그룹에서만 허용되도록 설정되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/pam.d/su; cat /etc/group | grep wheel; ls -al /bin/su\","

    pam_wheelso_count=$(grep -vE '^#|^\s#' /etc/pam.d/su | grep 'pam_wheel.so')
    su_file_permission=$(stat -c %a /bin/su)
    su_file_permission=$(printf "%04d" "$su_file_permission")

    first_digit="${su_file_permission:0:1}"
    second_digit="${su_file_permission:1:1}"
    third_digit="${su_file_permission:2:1}"
    fourth_digit="${su_file_permission:3:1}"

    declare -a details
    declare -a solutions

    if [ -z "$pam_wheelso_count" ]; then
        details+=("\"/etc/pam.d/su 파일에 pam_wheel.so 모듈이 설정되어 있지 않은 상태입니다.\"")
        if [ "$first_digit" -le 4 ] &&  [ "$second_digit" -le 7 ] &&  [ "$third_digit" -le 5 ] &&  [ "$fourth_digit" -le 0 ] ; then
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/pam.d/su파일에 pam_wheel.so 모듈을 설정하여 주시기 바랍니다\"")
        else
            details+=("\"/bin/su 파일의 권한이 $su_file_permission 인 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/pam.d/su파일에 pam_wheel.so 모듈을 설정하여 주시고 /bin/su파일의 권한을 4750이하로 설정하여 주시기 바랍니다.\"")
        fi
    else
        if [ "$first_digit" -le 4 ] &&  [ "$second_digit" -le 7 ] &&  [ "$third_digit" -le 5 ] &&  [ "$fourth_digit" -le 0 ] ; then
            echo "    \"status\":\"[양호]\","
            echo "    \"details\": ["
            echo "      \"/etc/pam.d/su 파일에 pam_wheel.so 모듈이 설정되어 있으며 /bin/su 파일의 권한이 $su_file_permission 인 상태입니다.\""
            echo "    ]"
        else
            details+=("\"/bin/su 파일의 권한이 $su_file_permission 인 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 /bin/su파일의 권한을 4750이하로 설정하여 주시기 바랍니다.\"")
        fi
    fi

    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_46() {
    echo "  {"
    echo "    \"Item\": \"U-46\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.7 패스워드 최소 길이 설정\","
    echo "    \"Description\": \"시스템 정책에 패스워드 최소(8자 이상) 길이 설정이 적용되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/login.defs | grep PASS\","
    
    declare -a details
    declare -a solutions

    if [ -f /etc/login.defs ]; then
        minlen=$(awk '!/^\s*#/ && /^\s*PASS_MIN_LEN/{print $2}' /etc/login.defs)
        if [ -n "$minlen" ] && [ "$minlen" -ge 8 ]; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"/etc/login.defs 파일에 패스워드 최소 길이가 8자 이상으로 설정되어 있는 상태입니다.\""
            echo "    ]"
        else
            if [ -z "$minlen" ]; then
                details+=("\"%s 파일에 패스워드 최소 길이가 설정되어 있지 않습니다.\"")
            else
                details+=("\"/etc/login.defs 파일에 패스워드 최소 길이가 \\\"$minlen\\\" 로 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요통신기반시설 가이드를 참고하시어 /etc/login.defs 파일 내 패스워드 최소 자리수를 \\\"8\\\"이상으로 설정하여 주시기 바랍니다.\"")
            fi
        fi
    else
                echo "    \"status\": \"[N/A]\","
                echo "    \"details\": ["
                echo "      \"/etc/login.defs 파일이 존재하지 않습니다.\""
                echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_47() {
    echo "  {"
    echo "    \"Item\": \"U-47\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.8 패스워드 최대 사용기간 설정\","
    echo "    \"Description\": \"시스템 정책에 패스워드 최대(90일 이하) 사용기간 설정이 적용되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/login.defs | grep PASS\","

    declare -a details
    declare -a solutions

    if [ -f /etc/login.defs ]; then
        maxdays=$(awk '!/^\s*#/ &&/^\s*PASS_MAX_DAYS/{print $2}' /etc/login.defs)
        if [ -n "$maxdays" ] && [ "$maxdays" -le 90 ]; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"/etc/login.defs 파일에 패스워드 최대 사용기간이 $maxdays 일로 설정되어 있는 상태입니다.\""
            echo "    ]"
        else
            if [ -z "$maxdays" ]; then
                details+=("\"/etc/login.defs 파일에 패스워드 최대 사용기간이 설정되어 있지 않은 상태입니다.\"")
            else
                details+=("\"/etc/login.defs 파일에서 패스워드 최대 사용기간이 \\\"$maxdays\\\" 로 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요통신기반시설 가이드를 참고하여 /etc/login.defs 파일의 패스워드 최대 사용기간을 90일 이하로 설정하여 주시기 바랍니다.\"")
            fi
        fi
    else
        details+=("\"/etc/login.defs 파일이 존재하지 않는 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하여 /etc/login.defs 파일의 패스워드 최대 사용기간을 90일 이하로 설정하여 주시기 바랍니다.\"")
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_48() {
    echo "  {"
    echo "    \"Item\": \"U-48\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.9 패스워드 최소 사용기간 설정\","
    echo "    \"Description\": \"시스템 정책에 패스워드 최소 사용기간 설정이 적용되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/login.defs | grep PASS\","

    declare -a details
    declare -a solutions

    if [ -f /etc/login.defs ]; then
        mindays=$(awk '!/^\s*#/ && /^\s*PASS_MIN_DAYS/{print $2}' /etc/login.defs)
        if [ -n "$mindays" ] && [ "$mindays" -ge 1 ]; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"/etc/login.defs 파일에 패스워드 최소 사용기간이 $mindays 일로 설정되어 있는 상태입니다.\""
            echo "    ]"
        else
            if [ -z "$mindays" ]; then
                details+=("\"/etc/login.defs 파일에 패스워드 최소 사용기간이 설정되어 있지 않은 상태입니다.\"")
            else
                details+=("\"/etc/login.defs 파일에서 패스워드 최소 사용기간이 $mindays 일로 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요통신기반시설 가이드를 참고하여 /etc/login.defs 파일의 패스워드 최소 사용기간을 1일 이상으로 설정하여 주시기 바랍니다.\"")
            fi
        fi
    else
        details+=("\"/etc/login.defs 파일이 존재하지 않는 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하여 /etc/login.defs 파일의 패스워드 최소 사용기간을 1일 이상으로 설정하여 주시기 바랍니다.\"")
    fi

    print_results details[@] solutions[@]

    
    echo "  },"
} >> "$rf"

U_49() {
    echo "  {"
    echo "    \"Item\": \"U-49\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.10 불필요한 계정 제거\","
    echo "    \"Description\": \"시스템 계정 중 불필요한 계정(퇴직, 전직, 휴직 등의 이유로 사용하지 않는 계정 및 장기적으로 사용하지 않는 계정 등)이 존재하는지 점검\","
    echo "    \"Command\": \"cat /etc/passwd | grep \\\"lp\\\|uucp\\\|nuucp\\\"; cat /etc/passwd | grep bash\","

    declare -a details
    declare -a solutions

    unnecessary_accounts=("lp" "uucp" "nuucp")
    bash_users=$(awk -F : '$7 ~ /bash/ && $3 >= 500 {print $1}' /etc/passwd)

    nologin=False
    vuln_acc=False
    
    acc_users=""

    for acc in "${unnecessary_accounts[@]}"; do
        if grep -q "^$acc:" /etc/passwd; then
            shell=$(awk -F : -v acc="$acc" '$1 == acc {print $7}' /etc/passwd)
            if [ "$shell" != "/sbin/nologin" ]; then
                vuln_acc=True
                acc_users+="$acc "
            fi
        fi
    done
    
    if [ -n "$bash_users" ]; then
        nologin=True
    fi

    if [ "$nologin" == "True" ] && [ "$vuln_acc" == "True" ]; then
        echo "    \"status\": \"[인터뷰]\","
        echo "    \"details\": ["
        echo -n "      \"로그인이 가능한 일반 사용자 계정("
        for user in $bash_users; do
			echo -n "$user "
		done
        echo ")의 목적이 확인되지 않아 담당자 확인이 필요합니다.\","
        echo "\"시스템 계정 중 불필요한 계정($acc_users)이 존재하는 상태입니다.\""
        echo "    ],"
        echo "    \"solutions\":\"주요정보통신기반시설 가이드를 참고하시어 시스템 계정 중 불필요한 계정($acc_users)을 삭제하시거나 /bin/false 또는 /sbin/nologin 쉘을 부여하여 주시기 바랍니다.\""
    elif [ "$nologin" == "False" ] && [ "$vuln_acc" == "True" ]; then
        echo "시스템 계정 중 불필요한 계정($acc_users)이 존재하는 상태입니다."
        echo "주요정보통신기반시설 가이드를 참고하시어 시스템 계정 중 불필요한 계정($acc_users)을 삭제하시거나 /bin/false 또는 /sbin/nologin 쉘을 부여하여 주시기 바랍니다."
    elif [ "$nologin" == "True" ] && [ "$vuln_acc" == "False" ]; then
        echo "    \"status\": \"[인터뷰]\","
        echo "    \"details\": ["
        echo -n "      \"로그인이 가능한 일반 사용자 계정("
        for user in $bash_users; do
			echo -n "$user "
		done
        echo ")의 목적이 확인되지 않아 담당자 확인이 필요합니다.\""
        echo "    ]"
    else
        echo "    \"status\":\"[양호]\","
        echo "    \"details\": ["
        echo "      \"시스템 계정 중 불필요한 계정이 존재하지 않는 상태입니다.\""
        echo "    ]"
    fi

    print_results details[@] solutions[@]

    
    echo "  },"    
} >> "$rf"

U_50() {
    echo "  {"
    echo "    \"Item\": \"U-50\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.11 관리자 그룹에 최소한의 계정 포함\","
    echo "    \"Description\": \"시스템 관리자 그룹에 최소한(root 계정과 시스템 관리에 허용된 계정)의 계정만 존재하는지 점검\","
    echo "    \"Command\": \"cat /etc/group | grep root\","

    declare -a details
    declare -a solutions

    root_group_members=$(grep '^root:' /etc/group | awk -F : '{print $4}')

    if [ -n "$root_group_members" ]; then
        non_root_users=""

        for user in $root_group_members; do
            if [ "$user" != "root" ]; then
                non_root_users+="$user "
            fi
        done

        if [ -n "$non_root_users" ]; then
            details+=("\"관리자 그룹(root)에 불필요한 계정($non_root_users)이 등록되어 있는 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 관리자 그룹(root) 내의 불필요한 계정을 삭제하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"관리자 그룹(root)에 타사용자가 추가되어 있지 않은 상태입니다.\""
            echo "    ]"
        fi
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"관리자 그룹(root)에 타사용자가 추가되어 있지 않은 상태입니다.\""
        echo "    ]"
    fi

    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_51() { #check
    echo "  {"
    echo "    \"Item\": \"U-51\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.12 계정이 존재하지 않는 GID 금지\","
    echo "    \"Description\": \"그룹(예: /etc/group) 설정 파일에 불필요한 그룹(계정이 존재하지 않고 시스템 관리나 운용에 사용되지 않는 그룹, 계정이 존재하고 시스템 관리나 운용에 사용되지 않는 그룹 등)이 존재하는지 점검\","
    # echo "    \"Command\": \"awk -F':' '/bash$/ {print $1 \\\":\\\" $4}' /etc/passwd | while IFS=: read user gid; do grep \\\":$gid:\\\" /etc/group; done\","
    echo "    \"Command\": \"cat /etc/passwd | grep bash; cat /etc/group\","
    
    declare -a details
    declare -a solutions

    bash_users=$(cat /etc/passwd | grep bash | awk -F : '{print $1}')
    vuln_users=""
    no_group_users=""

    for user in $bash_users; do
        group=$(grep "^$user:" /etc/group | awk -F : '{print $1}')
        if [ -n "$group" ]; then
            group_user=$(grep "^$user:" /etc/group | awk -F : '{print $4}')
            if [ -n "$group_user" ]; then
                vuln_users+="$user "
            fi
        else
            no_group_users+="$user "
        fi
    done

    if [ -n "$vuln_users" ]; then
        if [ -n "$no_group_users" ];then
            details+=("\"로그인이 가능한 사용자 계정($vuln_users)의 그룹 내 타사용자가 존재하며 $no_group_users 사용자의 그룹이 존재하지 않는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 관리자 검토 후 불필요한 계정 및 그룹일 경우 제거하여 주시기 바랍니다.\"")
        else
            details+=("\"로그인이 가능한 사용자 계정($vuln_users)의 그룹 내 타사용자가 존재하는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 관리자 검토 후 불필요한 계정일 경우 제거하여 주시기 바랍니다.\"")
        fi
    else  
        if [ -n "$no_group_users" ];then
            details+=("\"로그인이 가능한 $no_group_users 사용자의 그룹이 존재하지 않는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 관리자 검토 후 불필요한 계정일 경우 제거하여 주시기 바랍니다.\"")
        else 
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"로그인이 가능한 모든 사용자 계정의 그룹 내 타사용자가 존재하지 않고 모든 그룹이 존재하는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_52() {
    echo "  {"
    echo "    \"Item\": \"U-52\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.13 동일한 UID 금지\","
    echo "    \"Description\": \"'/etc/passwd' 파일 내 UID가 동일한 사용자 계정 존재 여부 점검\","
    echo "    \"Command\": \"cat /etc/passwd\","

    duplicated_uids=$(awk -F: '{print $3}' /etc/passwd | sort -n | uniq -d)

    if [[ -n $duplicated_uids ]]; then
        details+=("\"동일한 UID($duplicated_uids)로 설정된 사용자 계정이 존재하는 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하시어 동일한 UID로 설정된 사용자 계정의 UID를 변경하여 주시기 바랍니다.\"")
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"동일한 UID로 설정된 사용자 계정이 존재하지 않는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_53() {
    echo "  {"
    echo "    \"Item\": \"U-53\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.14 사용자 shell 점검\","
    echo "    \"Description\": \"로그인이 불필요한 계정(adm, sys, daemon 등)에 쉘 부여 여부 및 로그인 가능한 모든 계정의 bash_history 파일 존재 여부 점검\","
    echo "    \"Command\": \"cat /etc/passwd | grep \\\"daemon\\\|bin:\\\|sys\\\|adm\\\|listen\\\|nobody\\\|nobody4\\\|noaccess\\\|diag\\\|operator\\\|gopher\\\|games\\\|lp\\\|uucp\\\|nuucp\\\"\","

    declare -a details
    declare -a solutions

    bash_vulnerability=False
    unknown_vulnerability=False

    if [ -f /etc/passwd ]; then
        vuln_users=$(grep -E "^(daemon|bin:|sys|adm|listen|nobody|nobody4|noaccess|diag|operator|gopher|games|lp|uucp|nuucp):" /etc/passwd | awk -F : '$7!="/bin/false" && $7!="/sbin/nologin" {print $1}')
        if [ -n "$vuln_users" ]; then
            unknown_vulnerability=True
        fi
    fi
    
    bash_users=$(cat /etc/passwd | grep bash | awk -F : '{print $1}')
    Vulnerable_users=""
    for user in $bash_users; do
        user_home=$(grep "^$user:" /etc/passwd | awk -F : '{print $6}')
        if [ -f "$user_home/.bash_history" ]; then
            continue
        else
            Vulnerable_users+="$user "
        fi
    done

    if [ -n "$Vulnerable_users" ]; then
        bash_vulnerability=True
    fi
    
    if [ "$bash_vulnerability" == "False" ] && [ "$unknown_vulnerability" == "False" ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "\"로그인이 불필요한 계정에 /bin/false, sbin/nologin 쉘이 부여되어 있는 상태입니다.\","
        echo "\"로그인이 가능한 모든 계정의 bash_history 파일이 존재하는 상태입니다.\""
        echo "    ]"
    elif [ "$bash_vulnerability" == "True" ] && [ "$unknown_vulnerability" == "False" ]; then
        details+=("\"로그인이 가능한 사용자($Vulnerable_users)의 bash_history 파일이 존재하지 않는 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하시어 사용되지 않는 로그인 가능한 사용자 계정을 제거하거나 /bin/false 또는 /sbin/nologin 쉘을 부여하여 주시기 바랍니다.\"")
        
    elif [ "$bash_vulnerability" == "False" ] && [ "$unknown_vulnerability" == "True" ]; then
        for user in $vuln_users; do
            echo -n "$user "
        done
        details+=("\"로그인이 불필요한 계정($user)에 /bin/false, /sbin/nologin 쉘이 부여되지 않은 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하시어 로그인이 불필요한 계정에 /bin/false 또는 /sbin/nologin 쉘을 부여하여 주시기 바랍니다.\"")
    else
        for user in $vuln_users; do
            echo -n "$user "
        done
        details+=("\"로그인이 불필요한 계정($user)에 /bin/false, /sbin/nologin 쉘이 부여되지 않은 상태입니다.\"")
        details+=("\"로그인이 가능한 일반사용자($Vulnerable_users)의 bash_history 파일이 존재하지 않는 상태입니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하시어 로그인이 불필요한 계정에 /bin/false 또는 /sbin/nologin 쉘을 부여하여 주시기 바랍니다.\"")
        solutions+=("\"주요통신기반시설 가이드를 참고하시어 사용되지 않는 로그인 가능한 사용자 계정을 제거하거나 /bin/false 또는 /sbin/nologin 쉘을 부여하여 주시기 바랍니다.\"")
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_54() {
    echo "  {"
    echo "    \"Item\": \"U-54\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"1. 계정관리\","
    echo "    \"Sub_Category\": \"1.15 Session Timeout 설정\","
    echo "    \"Description\": \"사용자 쉘에 대한 환경설정 파일에서 session timeout 설정 여부 점검\","
    echo "    \"Command\": \"cat /etc/profile\","

    declare -a details
    declare -a solutions

    tmout_value=$(grep -E '^TMOUT=' /etc/profile | awk -F '=' '{print $2}')

    if [ -z "$tmout_value" ]; then
        details+=("\"Session timeout 값이 설정되어 있지 않은 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"Session Timeout\\\" 값을 \\\"600\\\" 이하로 설정하여 주시기 바랍니다.\"")
    else
        if [ "$tmout_value" -le 600 ]; then            
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"Session timeout값이 \\\"$tmout_value\\\" 인 상태입니다.\""
            echo "    ]"
        else
            details+=("\"Session timeout 값이 \\\"$tmout_value\\\" 인 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"Session timeout\\\" 값을 \\\"600\\\" 이하로 설정하여 주시기 바랍니다.\"")
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_05() {
    echo "  {"
    echo "    \"Item\": \"U-05\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.1 root홈, 패스 디렉터리 권한 및 패스 설정\","
    echo "    \"Description\": \"root 계정의 PATH 환경변수에 \\\".\\\" 또는 \\\"::\\\"이 포함되어 있는지 점검\","
    echo "    \"Command\": \"echo \$PATH\","

    declare -a details
    declare -a solutions

	if [ `echo $PATH | grep -E '\.:|::' | wc -l` -gt 0 ]; then
        details+=("\"PATH 환경 변수 내에 \\\".\\\" 또는 \\\"::\\\"이 포함되어 있는 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 PATH 환경 변수 내에 \\\".\\\" 또는 \\\"::\\\"를 제거하여 주시기 바랍니다.\"")
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"PATH 환경변수 맨 앞 및 중간에 \\\".\\\" 또는 \\\"::\\\"이 포함되어 있지 않은 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_06() {
    echo "  {"
    echo "    \"Item\": \"U-06\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.2 파일 및 디렉터리 소유자 설정\","
    echo "    \"Description\": \"소유자 불분명한 파일이나 디렉토리가 존재하는지 점검\","
    echo "    \"Command\": \"find / -nouser -or -nogroup\","

	if [ `find / \( -nouser -or -nogroup \) 2>/dev/null | wc -l` -gt 0 ]; then
        echo "    \"status\": \"[인터뷰]\","
        echo "    \"details\": ["
        echo "      \"소유자가 확인되지 않은 다수의 파일이 존재하고 있어 담당자 확인이 필요합니다.\""
        echo "    ]"
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"소유자가 존재하지 않는 파일 및 디렉터리가 존재하지 않은 상태입니다.\""
        echo "    ]"
	fi
    
    echo "  },"  
} >> "$rf"

U_07() {
    echo "  {"
    echo "    \"Item\": \"U-07\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.3 /etc/passwd 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/passwd 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"cat /etc/passwd\","

    declare -a details
    declare -a solutions

	if [ -f /etc/passwd ]; then		
		etc_passwd_owner_name=`ls -l /etc/passwd | awk '{print $3}'`
		if [[ $etc_passwd_owner_name =~ root ]]; then
			etc_passwd_permission=`stat -c %03a /etc/passwd`
			etc_passwd_owner_permission=`stat -c %03a /etc/passwd | cut -c1`
			etc_passwd_group_permission=`stat -c %03a /etc/passwd | cut -c2`
			etc_passwd_other_permission=`stat -c %03a /etc/passwd | cut -c3`
			if [ $etc_passwd_owner_permission -eq 0 ] || [ $etc_passwd_owner_permission -eq 2 ] || [ $etc_passwd_owner_permission -eq 4 ] || [ $etc_passwd_owner_permission -eq 6 ]; then
				if [ $etc_passwd_group_permission -eq 0 ] || [ $etc_passwd_group_permission -eq 4 ]; then
					if [ $etc_passwd_other_permission -eq 0 ] || [ $etc_passwd_other_permission -eq 4 ]; then
                        echo "    \"status\": \"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"/etc/passwd 파일의 소유자가 root이고, 권한이 644 이하인 상태입니다.\""
                        echo "    ]"
                        echo "  },"  
                        return 0
                    fi
				fi
			fi
            details+=("\"/etc/passwd 파일에 대한 권한이 ${etc_passwd_permission} 으로 취약한 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/passwd 파일 권한을 644(-rw-r--r--) 이하로 설정하여 주시기 바랍니다.\"")
            print_results details[@] solutions[@]
            echo "  },"  
            return 0
        else
            details+=("\"/etc/passwd 파일 소유자(owner)를 root가 아닌 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/passwd 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
        fi
	else
        echo "    \"status\": \"[N/A]\","
        echo "    \"details\": ["
        echo "      \"/etc/passwd 파일이 존재하지 않습니다.\""
        echo "    ]"
        echo "  }," 
        return 0
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_08() {
    echo "  {"
    echo "    \"Item\": \"U-08\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.4 /etc/shadow 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/shadow 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"cat /etc/shadow\","

    declare -a details
    declare -a solutions

	if [ -f /etc/shadow ]; then
		etc_shadow_owner_name=`ls -l /etc/shadow | awk '{print $3}'`
		if [[ $etc_shadow_owner_name =~ root ]]; then
		etc_shadow_permission=`stat -c %03a /etc/shadow`
		etc_shadow_owner_permission=`stat -c %03a /etc/shadow | cut -c1`
		etc_shadow_group_permission=`stat -c %03a /etc/shadow | cut -c2`
		etc_shadow_other_permission=`stat -c %03a /etc/shadow | cut -c3`
			if [ $etc_shadow_owner_permission -eq 0 ] || [ $etc_shadow_owner_permission -eq 4 ]; then
				if [ $etc_shadow_group_permission -eq 0 ]; then
					if [ $etc_shadow_other_permission -eq 0 ]; then
						echo "    \"status\": \"[양호]\","
						echo "    \"details\": ["
                        echo "      \"/etc/shadow 파일의 소유자가 root이고, 권한이 400 이하인 상태입니다.\""
						echo "    ]"
                        echo "  },"  
                        return 0
					fi
				fi
			fi
            details+=("\"/etc/shadow 파일에 대한 권한이 ${etc_shadow_permission} 으로 취약한 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/shadow 파일 권한을 400(-r--------) 이하로 설정하여 주시기 바랍니다.\"")
            print_results details[@] solutions[@]

            
            echo "  },"
            return 0  
		else
            details+=("\"/etc/shadow 파일의 소유자(owner)가 root가 아닌 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/shadow 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
		fi
	else
		echo "    \"status\": \"[N/A]\","
		echo "    \"details\": ["
        echo "      \"/etc/shadow 파일이 존재하지 않습니다.\""
        echo "    ]"
        echo "  },"  
		return 0
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_09() {
    echo "  {"
    echo "    \"Item\": \"U-09\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.5 /etc/hosts 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/hosts 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"cat /etc/hosts\","

    declare -a details
    declare -a solutions

	if [ -f /etc/hosts ]; then
		etc_hosts_owner_name=`ls -l /etc/hosts | awk '{print $3}'`
		if [[ $etc_hosts_owner_name =~ root ]]; then
			etc_hosts_permission=`stat -c %03a /etc/hosts`
			etc_hosts_owner_permission=`stat -c %03a /etc/hosts | cut -c1`
			etc_hosts_group_permission=`stat -c %03a /etc/hosts | cut -c2`
			etc_hosts_other_permission=`stat -c %03a /etc/hosts | cut -c3`
			if [ $etc_hosts_owner_permission -eq 0 ] || [ $etc_hosts_owner_permission -eq 2 ] || [ $etc_hosts_owner_permission -eq 4 ] || [ $etc_hosts_owner_permission -eq 6 ]; then
				if [ $etc_hosts_group_permission -eq 0 ]; then
					if [ $etc_hosts_other_permission -eq 0 ]; then
						echo "    \"status\": \"[양호]\","
						echo "    \"details\": ["
                        echo "      \"/etc/hosts 파일의 소유자가 root이고, 권한이 600인 이하인 상태입니다.\""
                        echo "    ]"
                        echo "  },"  
						return 0
					fi
				fi
			fi
            details+=("\"/etc/hosts 파일에 대한 권한이 ${etc_hosts_permission} 으로 설정되어 있는 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/hosts 파일 권한을 600(-rw-------) 이하로 설정하여 주시기 바랍니다.\"")
            
            print_results details[@] solutions[@]

            
            echo "  }," 
            return 0
		else
            details+=("\"/etc/hosts 파일의 소유자(owner)가 root가 아닌 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/hosts 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
		fi
	else
		echo "    \"status\": \"[N/A]\","
		echo "    \"details\": ["
        echo "      \"/etc/hosts 파일이 존재하지 않습니다.\""
        echo "    ]"
        echo "  },"  
		return 0
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_10() {
    echo "  {"
    echo "    \"Item\": \"U-10\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.6 /etc/(x)inetd.conf 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/(x)inetd.conf 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"find / -name xinetd.conf\","

    declare -a details
    declare -a solutions

	if [ -f /etc/inetd.conf ]; then
		etc_inetd_owner_name=`ls -l /etc/inetd.conf | awk '{print $3}'`
		if [[ $etc_inetd_owner_name =~ root ]]; then
			etc_inetd_permission=`stat -c %03a /etc/inetd.conf`
			etc_inetd_owner_permission=`stat -c %03a /etc/inetd.conf | cut -c1`
			etc_inetd_group_permission=`stat -c %03a /etc/inetd.conf | cut -c2`
			etc_inetd_other_permission=`stat -c %03a /etc/inetd.conf | cut -c3`
			if [ $etc_inetd_owner_permission -eq 0 ] || [ $etc_inetd_owner_permission -eq 2 ] || [ $etc_inetd_owner_permission -eq 4 ] || [ $etc_inetd_owner_permission -eq 6 ]; then
				if [ $etc_inetd_group_permission -eq 0 ]; then
					if [ $etc_inetd_other_permission -eq 0 ]; then
						echo "    \"status\": \"[양호]\","
						echo "    \"details\": ["
                        echo "      \"/etc/inetd.conf 파일의 소유자가 root이고, 권한이 600인 이하인 상태입니다.\""
                        echo "    ]"
					fi
				fi
			fi
            details+=("\"/etc/inetd.conf 파일에 대한 권한이 ${etc_inetd_permission} 으로 취약한 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/inetd.conf 파일 권한을 600(-rw-------) 이하로 설정하여 주시기 바랍니다.\"")
		else
            details+=("\"/etc/inetd.conf 파일의 소유자(owner)가 root가 아닌 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/inetd.conf 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
		fi
	else
		if [ -f /etc/xinetd.conf ]; then
			etc_xinetd_owner_name=`ls -l /etc/xinetd.conf | awk '{print $3}'`
			if [[ $etc_xinetd_owner_name =~ root ]]; then
				etc_xinetd_permission=`stat -c %03a /etc/inetd.conf`
				etc_xinetd_owner_permission=`stat -c %03a /etc/xinetd.conf | cut -c1`
				etc_xinetd_group_permission=`stat -c %03a /etc/xinetd.conf | cut -c2`
				etc_xinetd_other_permission=`stat -c %03a /etc/xinetd.conf | cut -c3`
				if [ $etc_xinetd_owner_permission -eq 0 ] || [ $etc_xinetd_owner_permission -eq 2 ] || [ $etc_xinetd_owner_permission -eq 4 ] || [ $etc_xinetd_owner_permission -eq 6 ]; then
					if [ $etc_xinetd_group_permission -eq 0 ]; then
						if [ $etc_xinetd_other_permission -eq 0 ]; then
							echo "    \"status\": \"[양호]\","
							echo "    \"details\": ["
                            echo "      \"/etc/xinetd.conf 파일의 소유자가 root이고, 권한이 600인 이하인 상태입니다.\""
                            echo "    ]"
						fi
					fi
				fi
				details+=("\"/etc/xinetd.conf 파일에 대한 권한이 ${etc_xinetd_permission} 으로 취약한 상태입니다.\"")
				solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/xinetd.conf 파일 권한을 600(-rw-------) 이하로 설정하여 주시기 바랍니다.\"")
			else
				details+=("\"/etc/xinetd.conf 파일의 소유자(owner)가 root가 아닌 상태입니다.\"")
				solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/xinetd.conf 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
			fi
		else
			echo "    \"status\": \"[N/A]\","
			echo "    \"details\": ["
            echo "      \"/etc/(x)inetd.conf 파일이 존재하지 않습니다.\""
            echo "    ]"
		fi
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_11() {
    echo "  {"
    echo "    \"Item\": \"U-11\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.7 /etc/(r)syslog.conf 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/(r)syslog.conf 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"ls -al /etc/syslog.conf /etc/rsyslog.conf /etc/syslog-ng.conf\","

    declare -a details
    declare -a solutions

	syslogconf_files=("/etc/rsyslog.conf" "/etc/syslog.conf" "/etc/syslog-ng.conf")
	file_exists_count=0
	judg=0
	wrong_owner=0

	for ((i=0; i<${#syslogconf_files[@]}; i++))
	do
		if [ -f ${syslogconf_files[$i]} ]; then
			((file_exists_count++))
			syslogconf_file_owner_name=`ls -l ${syslogconf_files[$i]} | awk '{print $3}'`
			if [[ $syslogconf_file_owner_name = root ]] || [[ $syslogconf_file_owner_name = bin ]] || [[ $syslogconf_file_owner_name = sys ]]; then
				syslogconf_file_owner_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c1`
				syslogconf_file_group_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c2`
				syslogconf_file_other_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c3`
				if [ $syslogconf_file_owner_permission -eq 0 ] || [ $syslogconf_file_owner_permission -eq 2 ] || [ $syslogconf_file_owner_permission -eq 4 ] || [ $syslogconf_file_owner_permission -eq 6 ]; then
					if [ $syslogconf_file_group_permission -eq 0 ] || [ $syslogconf_file_group_permission -eq 2 ] || [ $syslogconf_file_group_permission -eq 4 ]; then
						if [ $syslogconf_file_other_permission -eq 0 ]; then
							((judg++))
						fi
					fi
				fi
			else
				((wrong_owner++))
			fi
		fi
	done
	if [ $file_exists_count -eq 0 ]; then
		echo "    \"status\": \"[N/A]\","
		echo "    \"details\": ["
        echo "      \"/etc/syslog.conf 파일이 존재하지 않습니다.\""
        echo "    ]"
	else
		if [ $judg -eq $file_exists_count ]; then
			echo "    \"status\": \"[양호]\","
			echo "    \"details\": ["
            echo "      \"/etc/syslog.conf 파일의 소유자가 root(또는 bin, sys)이고, 권한이 640 이하인 상태입니다.\""
            echo "    ]"
		else
			if [ $wrong_owner -eq 0 ]; then
				for ((i=0; i<${#syslogconf_files[@]}; i++))
				do
					if [ -f ${syslogconf_files[$i]} ]; then
						syslogconf_file_permission=`stat -c %03a ${syslogconf_files[$i]}`
						syslogconf_file_owner_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c1`
						syslogconf_file_group_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c2`
						syslogconf_file_other_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c3`
						if [ $syslogconf_file_owner_permission -eq 0 ] || [ $syslogconf_file_owner_permission -eq 2 ] || [ $syslogconf_file_owner_permission -eq 4 ] || [ $syslogconf_file_owner_permission -eq 6 ]; then
							if [ $syslogconf_file_group_permission -eq 0 ] || [ $syslogconf_file_group_permission -eq 2 ] || [ $syslogconf_file_group_permission -eq 4 ]; then
								if [ $syslogconf_file_other_permission -eq 0 ]; then
									continue
								fi
							fi
						fi
						details+=("\"${syslogconf_files[$i]} 파일에 대한 권한이 ${syslogconf_file_permission} 으로 설정되어 있는 상태입니다.\"")
					fi
				done
				for ((i=0; i<${#syslogconf_files[@]}; i++))
				do
					if [ -f ${syslogconf_files[$i]} ]; then
						syslogconf_file_owner_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c1`
						syslogconf_file_group_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c2`
						syslogconf_file_other_permission=`stat -c %03a ${syslogconf_files[$i]} | cut -c3`
						if [ $syslogconf_file_owner_permission -eq 0 ] || [ $syslogconf_file_owner_permission -eq 2 ] || [ $syslogconf_file_owner_permission -eq 4 ] || [ $syslogconf_file_owner_permission -eq 6 ]; then
							if [ $syslogconf_file_group_permission -eq 0 ] || [ $syslogconf_file_group_permission -eq 2 ] || [ $syslogconf_file_group_permission -eq 4 ]; then
								if [ $syslogconf_file_other_permission -eq 0 ]; then
									continue
								fi
							fi
						fi
						solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 ${syslogconf_files[$i]} 파일의 권한을 640(-rw-r-----) 이하로 설정하여 주시기 바랍니다.\"")
					fi
				done
			else
				for ((i=0; i<${#syslogconf_files[@]}; i++))
				do
					if [ -f ${syslogconf_files[$i]} ]; then
						syslogconf_file_owner_name=`ls -l ${syslogconf_files[$i]} | awk '{print $3}'`
						if [[ $syslogconf_file_owner_name =~ root ]] || [[ $syslogconf_file_owner_name =~ bin ]] || [[ $syslogconf_file_owner_name =~ sys ]]; then	
							details+=("\"${syslogconf_files[$i]} 파일의 소유자(owner)가 root(또는 bin, sys)가 아닌 상태입니다.\"")
						fi
					fi
				done
				for ((i=0; i<${#syslogconf_files[@]}; i++))
				do
					if [ -f ${syslogconf_files[$i]} ]; then
						syslogconf_file_owner_name=`ls -l ${syslogconf_files[$i]} | awk '{print $3}'`
						if [[ $syslogconf_file_owner_name =~ root ]] || [[ $syslogconf_file_owner_name =~ bin ]] || [[ $syslogconf_file_owner_name =~ sys ]]; then	
							solutions+=("\"주요정보통신기반시설 가이드를 참고하시어  ${syslogconf_files[$i]} 파일의 소유자(owner)를 root(또는 bin, sys)로 설정하여 주시기 바랍니다.\"")
						fi
					fi
				done
			fi
		fi
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_12() {
    echo "  {"
    echo "    \"Item\": \"U-12\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.8 /etc/services 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/services 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"ls -al /etc/services\","

    declare -a details
    declare -a solutions

	if [ -f /etc/services ]; then
		etc_services_owner_name=`ls -l /etc/services | awk '{print $3}'`
		if [[ $etc_services_owner_name =~ root ]] || [[ $etc_services_owner_name =~ bin ]] || [[ $etc_services_owner_name =~ sys ]]; then
			etc_services_permission=`stat -c %03a /etc/services`
			etc_services_owner_permission=`stat -c %03a /etc/services | cut -c1`
			etc_services_group_permission=`stat -c %03a /etc/services | cut -c2`
			etc_services_other_permission=`stat -c %03a /etc/services | cut -c3`
			if [ $etc_services_owner_permission -eq 0 ] || [ $etc_services_owner_permission -eq 2 ] || [ $etc_services_owner_permission -eq 4 ] || [ $etc_services_owner_permission -eq 6 ]; then
				if [ $etc_services_group_permission -eq 0 ] || [ $etc_services_group_permission -eq 2 ] || [ $etc_services_group_permission -eq 4 ]; then
					if [ $etc_services_other_permission -eq 0 ] || [ $etc_services_other_permission -eq 2 ] || [ $etc_services_other_permission -eq 4 ]; then
						echo "    \"status\": \"[양호]\","
						echo "    \"details\": ["
                        echo "      \"/etc/services 파일의 소유자가 root(또는 bin, sys)이고, 권한이 644 이하인 상태입니다.\""
                        echo "    ]"
                        echo "  },"  
						return 0
					fi
				fi
			fi
			details+=("\"/etc/services 파일에 대한 권한이 ${etc_services_permission} 으로 취약한 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/services 파일 권한을 644(-rw-r--r--) 이하로 설정하여 주시기 바랍니다.\"")
            print_results details[@] solutions[@]

            
            echo "  }," 
            return 0
		else
			details+=("\"/etc/services 파일의 파일의 소유자(owner)가 root(또는 bin, sys)가 아닌 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /etc/services 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
		fi
	else
		echo "    \"status\": \"[N/A]\","
		echo "    \"details\": ["
        echo "      \"/etc/services 파일이 존재하지 않습니다.\""
        echo "    ]"
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_13() {
    echo "  {"
    echo "    \"Item\": \"U-13\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.9 SUID, SGID 설정 파일 점검\","
    echo "    \"Description\": \"불필요하거나 악의적인 파일의 SUID, SGID 설정 여부 점검\","
    echo "    \"Command\": \"ls -al /sbin/dump /sbin/restore /sbin/unix_chkpwd /usr/bin/at /usr/bin/lpq /usr/bin/lpq-lpd /usr/bin/lpr /usr/bin/lpr-lpd /usr/bin/lprm /usr/bin/lprm-lpd /usr/bin/newgrp /usr/sbin/lpc /usr/sbin/lpc-lpd /usr/sbin/traceroute\","

    declare -a details
    declare -a solutions

	executables=("/sbin/dump" "/sbin/restore" "/sbin/unix_chkpwd" "/usr/bin/at" "/usr/bin/lpq" "/usr/bin/lpq-lpd" "/usr/bin/lpr" "/usr/bin/lpr-lpd" "/usr/bin/lprm" "/usr/bin/lprm-lpd" "/usr/bin/newgrp" "/usr/sbin/lpc" "/usr/sbin/lpc-lpd" "/usr/sbin/traceroute")
	for ((i=0; i<${#executables[@]}; i++))
	do
		if [ -f ${executables[$i]} ]; then
			if [ `ls -l ${executables[$i]} | awk '{print substr($1,2,9)}' | grep -i 's' | wc -l` -gt 0 ]; then
				details+=("\"주요 실행 파일의 권한에 SUID나 SGID에 대한 설정이 부여되어 있는 상태입니다.\"")
				solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 주요 실행 파일의 권한에 부여되어있는 SUID나 SGID에 대한 설정을 제거하여 주시기 바랍니다.\"")
                print_results details[@] solutions[@]

                
                echo "  },"  
                return 0
			fi
		fi
	done
	echo "    \"status\": \"[양호]\","
	echo "    \"details\": ["
    echo "      \"주요 실행파일의 권한에 SUID와 SGID에 대한 설정이 부여되어 있지 않은 상태입니다.\""
    echo "    ]"
    echo "  },"  

} >> "$rf"

U_14() {
    echo "  {"
    echo "    \"Item\": \"U-14\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.10 사용자, 시스템 시작파일 및 환경파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"홈 디렉토리 내의 환경변수 파일에 대한 소유자 및 접근권한이 관리자 또는 해당 계정으로 설정되어 있는지 점검\","
    # echo "    \"Command\": \"find /home /root -mindepth 1 -maxdepth 2 -type d -exec sh -c 'grep -q ":$1:" /etc/passwd && ls -ald $1/.bash*' sh {} \;\","
    echo "    \"Command\": \"cat /etc/passwd | grep bash; ls -al /root/.bash* /home/*/.bash*\","

    declare -a details
    declare -a solutions

	file_exists_count=0
	judg=0
	user_homedirectory_paths=($(cat /etc/passwd | grep bash | awk -F: '{print $6}'))
	for user_homedirectory_path in "${user_homedirectory_paths}"
	do
		((file_exists_count++))
		for user_homedirectory_file in ${user_homedirectory_path}/.bash*
		do
			user_homedirectory_file_owner=$(stat -c %U ${user_homedirectory_file})
			owner_compare=($(cat /etc/passwd | grep bash | grep ${user_homedirectory_path} | awk -F: '{print $1}'))
			user_homedirectory_file_group_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c2)
			user_homedirectory_file_other_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c3)
			if [[ $user_homedirectory_file_owner -eq $owner_compare ]] || [[ $user_homedirectory_file_owner = root ]]; then
				if [ $user_homedirectory_file_group_permission -eq 0 ] || [ $user_homedirectory_file_group_permission -eq 1 ] || [ $user_homedirectory_file_group_permission -eq 4 ] || [ $user_homedirectory_file_group_permission -eq 5 ]; then
					if [ $user_homedirectory_file_other_permission -eq 0 ] || [ $user_homedirectory_file_other_permission -eq 1 ] || [ $user_homedirectory_file_other_permission -eq 4 ] || [ $user_homedirectory_file_other_permission -eq 5 ]; then
						continue
					fi
				fi
			fi
			((judg++))
		done
	done
	if [ $file_exists_count -eq 0 ]; then
		echo "    \"status\": \"[N/A]\","
		echo "    \"details\": ["
        echo "      \"홈 디렉토리 환경변수 파일이 존재하지 않습니다.\""
        echo "    ]"
	else
		if [ $judg -eq 0 ]; then
			echo "    \"status\": \"[양호]\","
			echo "    \"details\": ["
            echo "      \"로그인이 가능한 모든 사용자의 환경변수 파일 소유자가 자기 자신으로 설정되어 있고 타사용자 쓰기권한이 부여되어 있지 않은 상태입니다.\""
            echo "    ]"
		else
			for user_homedirectory_path in "${user_homedirectory_paths}"
			do
				for user_homedirectory_file in ${user_homedirectory_path}/.bash*
				do
					user_homedirectory_file_owner=$(stat -c %U ${user_homedirectory_file})
					owner_compare=($(cat /etc/passwd | grep bash | grep ${user_homedirectory_path} | awk -F: '{print $1}'))
					user_homedirectory_file_group_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c2)
					user_homedirectory_file_other_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c3)
					if [[ $user_homedirectory_file_owner -eq $owner_compare ]] || [[ $user_homedirectory_file_owner = root ]]; then
						if [ $user_homedirectory_file_group_permission -eq 0 ] || [ $user_homedirectory_file_group_permission -eq 1 ] || [ $user_homedirectory_file_group_permission -eq 4 ] || [ $user_homedirectory_file_group_permission -eq 5 ]; then
							if [ $user_homedirectory_file_other_permission -eq 0 ] || [ $user_homedirectory_file_other_permission -eq 1 ] || [ $user_homedirectory_file_other_permission -eq 4 ] || [ $user_homedirectory_file_other_permission -eq 5 ]; then
								continue
							fi
						fi
						details+=("\"${user_homedirectory_file} 파일이 root와 소유자 외에 쓰기 권한이 부여된 상태입니다.\"")
					else
						details+=("\"${user_homedirectory_file} 파일의 소유자가 root 또는, 해당 계정으로 지정되지 않은 상태입니다.\"")
					fi
				done
			done
			for user_homedirectory_path in "${user_homedirectory_paths}"
			do
				for user_homedirectory_file in ${user_homedirectory_path}/.bash*
				do
					user_homedirectory_file_owner=$(stat -c %U ${user_homedirectory_file})
					owner_compare=($(cat /etc/passwd | grep bash | grep ${user_homedirectory_path} | awk -F: '{print $1}'))
					user_homedirectory_file_group_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c2)
					user_homedirectory_file_other_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c3)
					if [[ $user_homedirectory_file_owner -eq $owner_compare ]] || [[ $user_homedirectory_file_owner = root ]]; then
						if [ $user_homedirectory_file_group_permission -eq 0 ] || [ $user_homedirectory_file_group_permission -eq 1 ] || [ $user_homedirectory_file_group_permission -eq 4 ] || [ $user_homedirectory_file_group_permission -eq 5 ]; then
							if [ $user_homedirectory_file_other_permission -eq 0 ] || [ $user_homedirectory_file_other_permission -eq 1 ] || [ $user_homedirectory_file_other_permission -eq 4 ] || [ $user_homedirectory_file_other_permission -eq 5 ]; then
								continue
							fi
						fi
						solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 ${user_homedirectory_file} 파일의 root와 소유자 외에 쓰기 권한을 제거하여 주시기 바랍니다.\"")
					else
						solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 ${user_homedirectory_file} 파일의 소유자가 root 또는, 해당 계정으로 지정하여 주시기 바랍니다.\"")
					fi
				done
			done
		fi
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_15() {
    echo "  {"
    echo "    \"Item\": \"U-15\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.11 world writable 파일 점검\","
    echo "    \"Description\": \"불필요한 world writable 파일 존재 여부 점검\","
    echo "    \"Command\": \"find / ! \\\( -path '/proc*' -o -path '/sys/fs*' -o -path '/usr/local*' -prune \\\) -perm -2 -type f -exec ls -al {} \\\;\","
    
	if [ `find / ! \( -path '/proc*' -o -path '/sys/fs*' -o -path '/usr/local*' -prune \) -perm -2 -type f 2>/dev/null | wc -l` -gt 0 ]; then
		echo "    \"status\": \"[인터뷰]\","
		echo "    \"details\": ["
        echo "      \"/root 디렉터리 내 타사용자 쓰기권한이 부여된 파일이 존재하여 불필요하게 권한이 부여되어 있지 않은지 담당자 확인이 필요합니다.\""
        echo "    ]"
	else
		echo "    \"status\": \"[양호]\","
		echo "    \"details\": ["
        echo "      \"world writable 파일이 존재하지 않는 상태입니다.\""
        echo "    ]"
	fi
    
    echo "  },"  

} >> "$rf"

U_16() {
    echo "  {"
    echo "    \"Item\": \"U-16\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.12 /dev에 존재하지 않는 device 파일 점검\","
    echo "    \"Description\": \"존재하지 않는 device 파일 존재 여부 점검\","
    echo "    \"Command\": \"find /dev -type f -exec ls -al {} \\\;\","
    
	if [ `find /dev -type f 2>/dev/null | wc -l` -gt 0 ]; then
		echo "    \"status\": \"[인터뷰]\","
		echo "    \"details\": ["
        echo "      \"/dev 디렉터리 내 불필요하게 사용되고 있는 디바이스 파일이 존재하는지 담당자 확인이 필요합니다.\""
        echo "    ]"
	else
		echo "    \"status\": \"[양호]\","
		echo "    \"details\": ["
        echo "      \"/dev 디렉터리 내 불필요하게 사용되고 있는 디바이스 파일이 존재하지 않는 상태입니다.\""
        echo "    ]"
	fi
    echo "  },"  

} >> "$rf"

U_17() {
    echo "  {"
    echo "    \"Item\": \"U-17\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.13 \$HOME/.rhosts, hosts.equiv 사용 금지\","
    echo "    \"Description\": \"/etc/hosts.equiv 파일 및 .rhosts 파일 사용자를 root 또는 해당 계정으로 설정한 뒤 권한을 600으로 설정하고 해당 파일 설정에 '+' 설정(모든 호스트 허용)이 포함되지 않도록 설정되어 있는지 점검\","
    echo "    \"Command\": \"ls -al /etc/hosts.equiv /home/*.rhost; cat /etc/hosts.equiv /home/*.rhost\","

    declare -a details
    declare -a solutions

    if ! pgrep -x "xinetd" >/dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"xinetd\\\" 서비스가 비활성화되어 있는 상태입니다.\""
        echo "    ]"
        echo "  },"
        return 0
    fi

    service_active=false
    criteria_met=true
    r_services=("rsh" "rlogin" "rexec" "shell" "login" "exec")

    for service in "${r_services[@]}"; do
        if [ -f "/etc/xinetd.d/$service" ]; then
            is_disabled=$(grep "disable\s*=\s*yes" "/etc/xinetd.d/$service")
            if [ -z "$is_disabled" ]; then
                service_active=true
                criteria_met=false
            fi
        fi
    done

    if [ "$service_active" = false ]; then
        criteria_met=false
    else
        files=("/etc/hosts.equiv" "$(echo $HOME)/.rhosts")
        for file in "${files[@]}"; do
            if [ -f "$file" ]; then
                perm=$(stat -c "%a" "$file")
                owner=$(stat -c "%U" "$file")
                plus_check=$(grep '^+' "$file" | wc -l)
                
                read_perms="${perm:0:1}"
                write_perms="${perm:1:1}"
                execute_perms="${perm:2:1}"
                
                if [ "$owner" == "root" ] || [ "$owner" == "$(whoami)" ]; then
                    if [ "$read_perms" -le 6 ] && [ "$write_perms" -eq 0 ] && [ "$execute_perms" -eq 0 ] && [ "$plus_check" -eq 0 ]; then
                        echo "    \"status\": \"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"r계열 서비스에 모든 보안 설정이 되어 있는 상태입니다.\""
                        echo "    ]"
                        echo "  },"
                        return 0
                    else
                        criteria_met=false
                        if [ "$read_perms" -gt 6 ] || [ "$write_perms" -ne 0 ] || [ "$execute_perms" -ne 0 ]; then
                            details+=("\"$file 의 권한이 $perm 으로 설정되어 있는 상태입니다.\"")
                            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 의 권한을 600(-rw-------) 이하로 설정하여 주시기 바랍니다.\"")
                            print_results details[@] solutions[@]
                            
                            echo "  },"
                            return 0
                        fi
                        if [ "$plus_check" -ne 0 ]; then
                            details+=("\"$file 파일에 '+' 설정이 포함되어 있는 상태입니다.\"")
                            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 파일에서 '+' 설정을 제거하여 주시기 바랍니다.\"")
                            print_results details[@] solutions[@]
                            
                            echo "  },"
                            return 0
                        fi
                    fi
                else
                    criteria_met=false
                    details+=("\"$file 파일의 소유자가 root 또는 해당 계정이 아닌 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 파일의 소유자를 root 또는 해당 계정으로 설정하여 주시기 바랍니다.\"")
                    print_results details[@] solutions[@]
                    
                    echo "  },"
                    return 0
                fi
            fi
        done
    fi
    echo "    \"status\": \"[N/A]\","
    echo "    \"details\": ["
    echo "      \"r계열 서비스 설정 파일이 존재하지 않습니다.\""
    echo "    ]"
    echo "  },"
} >> "$rf"


U_18() {
    echo "  {"
    echo "    \"Item\": \"U-18\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.14 접속 IP 및 포트 제한\","
    echo "    \"Description\": \"허용할 호스트에 대한 접속 IP 주소 제한 및 포트 제한 설정 여부 점검\","
    echo "    \"Command\": \"cat /etc/hosts.deny /etc/hosts.allow\","

    declare -a details
    declare -a solutions

	if [ -f /etc/hosts.deny ]; then
		etc_hostsdeny_allall_count=`grep -vE '^#|^\s#' /etc/hosts.deny | awk '{gsub(" ", "", $0); print}' | grep -i 'all:all' | wc -l`
		if [ $etc_hostsdeny_allall_count -gt 0 ]; then
			if [ -f /etc/hosts.allow ]; then
				etc_hostsallow_allall_count=`grep -vE '^#|^\s#' /etc/hosts.allow | awk '{gsub(" ", "", $0); print}' | grep -i 'all:all' | wc -l`
				if [ $etc_hostsallow_allall_count -gt 0 ]; then
					details+=("\"/etc/hosts.allow 파일에 'ALL : ALL' 설정이 있는 상태입니다.\"")
					solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 접속을 허용할 특정 호스트에 대한 IP 주소 및 포트 제한을 설정하여 주시기 바랍니다.\"")
				else
					echo "    \"status\": \"[양호]\","
					echo "    \"details\": ["
                    echo "      \"접속을 허용할 특정 호스트에 대한 IP 주소 및 포트 제한을 설정되어 있는 상태입니다.\""
                    echo "    ]"
				fi
			else
				echo "    \"status\": \"[양호]\","
				echo "    \"details\": ["
                echo "      \"접속을 허용할 특정 호스트에 대한 IP 주소 및 포트 제한을 설정되어 있는 상태입니다.\""
                echo "    ]"
			fi
		else
			details+=("\"/etc/hosts.deny 파일에 'ALL : ALL' 설정이 없는 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 접속을 허용할 특정 호스트에 대한 IP 주소 및 포트 제한을 설정하여 주시기 바랍니다.\"")
		fi
	else
		echo "    \"status\": \"[인터뷰]\","
		echo "    \"details\": ["
        echo "      \"/etc/hosts.deny 파일이 존재하지 않는 상태입니다. 서버접근제어 솔루션 및 내부 방화벽을 통해 서버 접근을 통제하고 있는지 담당자 확인이 필요합니다.\""
        echo "    ]"
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_55() {
    echo "  {"
    echo "    \"Item\": \"U-55\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.15 hosts.lpd 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"/etc/hosts.lpd 파일의 삭제 및 권한 적절성 점검\","
    echo "    \"Command\": \"ls -al /etc/hosts.lpd\","
    
    declare -a details
    declare -a solutions

	if [ -f /etc/hosts.lpd ]; then
		etc_hostslpd_owner_name=`ls -l /etc/hosts.lpd | awk '{print $3}'`
		if [[ $etc_hostslpd_owner_name = root ]]; then
			etc_hostslpd_permission=`stat -c %03a /etc/hosts.lpd`
			if [ $etc_hostslpd_permission -eq 600 ] || [ $etc_hostslpd_permission -eq 400 ] || [ $etc_hostslpd_permission -eq 200 ] || [ $etc_hostslpd_permission -eq 000 ]; then
				echo "    \"status\": \"[양호]\","
				echo "    \"details\": ["
                echo "      \"/hosts.lpd 파일의 소유자가 root이고 권한이 600 이하인 상태입니다.\""
                echo "    ]"
			else
				details+=("\"/etc/hosts.lpd 파일의 권한이 ${etc_hostslpd_permission}으로 취약한 상태입니다.\"")
				solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /hosts.lpd 파일 권한을 600(-rw-------) 이하로 설정하거나 삭제하여 주시기 바랍니다.\"")
			fi
		else
			details+=("\"/etc/hosts.lpd 파일의 소유자(owner)가 root가 아닌 상태입니다.\"")
			solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 /hosts.lpd 파일의 소유자(owner)를 root로 설정하여 주시기 바랍니다.\"")
		fi
	else
		echo "    \"status\": \"[양호]\","
		echo "    \"details\": ["
        echo "      \"/etc/hosts.lpd 파일이 존재하지 않는 상태입니다.\""
        echo "    ]"
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_56() {
    echo "  {"
    echo "    \"Item\": \"U-56\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.17 UMASK 설정 관리\","
    echo "    \"Description\": \"시스템 UMASK 값이 022 이상인지 점검\","
    echo "    \"Command\": \"cat /etc/profile\","

    declare -a details
    declare -a solutions

	profile_umasks_num=($(cat /etc/profile | grep umask | grep -vE '^#|^\s#' | awk '{print $NF}' | wc -l))
	if [ $profile_umasks_num -eq 0 ]; then
		details+=("\"UMASK 값이 설정되어 있지 않은 상태입니다.\"")
		solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 UMASK 값이 022 이상으로 설정하여 주시기 바랍니다.\"")

        print_results details[@] solutions[@]

        
        echo "  },"  
        return 0
	else
		profile_umasks=($(cat /etc/profile | grep umask | grep -vE '^#|^\s#' | awk '{print $NF}'):1:1)
		for umask_value in "${profile_umasks[@]}"
		do
			umask_string=$(echo "$umask_value")
			if [ ${umask_string:1:1} -eq 0 ] || [ ${umask_string:1:1} -eq 1 ] || [ ${umask_string:1:1} -eq 4 ] || [ ${umask_string:1:1} -eq 5 ]; then
				details+=("\"UMASK 값이 022 이상으로 설정되어 있지 않은 상태입니다.\"")
				solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 UMASK 값을 022 이상으로 설정하여 주시기 바랍니다.\"")

                print_results details[@] solutions[@]

                
                echo "  },"  
                return 0
			else
				if [ ${umask_string:2:1} -eq 0 ] || [ ${umask_string:2:1} -eq 1 ] || [ ${umask_string:2:1} -eq 4 ] || [ ${umask_string:2:1} -eq 5 ]; then
					details+=("\"UMASK 값이 022 이상으로 설정되어 있지 않은 상태입니다.\"")
					solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 UMASK 값을 022 이상으로 설정하여 주시기 바랍니다.\"")

                    print_results details[@] solutions[@]

                    
                    echo "  },"  
                    return 0
				fi
			fi
		done
		echo "    \"status\": \"[양호]\","
		echo "    \"details\": ["
        echo "      \"UMASK 값이 022 이상으로 설정되어 있는 상태입니다.\""
        echo "    ]"
	fi
    echo "  },"  
} >> "$rf"

U_57() {
    echo "  {"
    echo "    \"Item\": \"U-57\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.18 홈디렉토리 소유자 및 권한 설정\","
    echo "    \"Description\": \"홈 디렉토리의 소유자 외 타사용자가 해당 홈 디렉토리를 수정할 수 없도록 제한하는지 점검\","
    # echo "    \"Command\": \"find /home /root -mindepth 1 -maxdepth 2 -type d -exec sh -c 'grep -q ":$1:" /etc/passwd && ls -ald $1' sh {} \;\","
    echo "    \"Command\": \"cat /etc/passwd | grep bash; ls -ald /root/ /home/*/\","

    declare -a details
    declare -a solutions

	file_exists_count=0
	judg=0
	user_homedirectory_paths=($(cat /etc/passwd | grep bash | awk -F: '{print $6}'))
	for user_homedirectory_path in "${user_homedirectory_paths}"
	do
		((file_exists_count++))
		for user_homedirectory_file in ${user_homedirectory_path}
		do
			user_homedirectory_file_owner=$(stat -c %U ${user_homedirectory_file})
			owner_compare=($(cat /etc/passwd | grep bash | grep ${user_homedirectory_path} | awk -F: '{print $1}'))
			user_homedirectory_file_other_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c3)
			if [[ $user_homedirectory_file_owner -eq $owner_compare ]]; then
				if [ $user_homedirectory_file_other_permission -eq 0 ] || [ $user_homedirectory_file_other_permission -eq 1 ] || [ $user_homedirectory_file_other_permission -eq 4 ] || [ $user_homedirectory_file_other_permission -eq 5 ]; then
					continue
				fi
			fi
			((judg++))
		done
	done
	if [ $file_exists_count -eq 0 ]; then
		echo "    \"status\": \"[N/A]\","
		echo "    \"details\": ["
        echo "      \"홈 디렉토리 환경변수 파일이 존재하지 않습니다.\""
        echo "    ]"
	else
		if [ $judg -eq 0 ]; then
			echo "    \"status\": \"[양호]\","
			echo "    \"details\": ["
            echo "      \"로그인이 가능한 사용자 홈 디렉터리의 소유주가 자기 자신이고, 타사용자 쓰기 권한이 부여되어 있지 않은 상태입니다.\""
            echo "    ]"
		else
			for user_homedirectory_path in "${user_homedirectory_paths}"
			do
				for user_homedirectory_file in ${user_homedirectory_path}/.bash*
				do
					user_homedirectory_file_owner=$(stat -c %U ${user_homedirectory_file})
					owner_compare=($(cat /etc/passwd | grep bash | grep ${user_homedirectory_path} | awk -F: '{print $1}'))
					user_homedirectory_file_other_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c3)
					if [[ $user_homedirectory_file_owner -eq $owner_compare ]]; then
						if [ $user_homedirectory_file_other_permission -eq 0 ] || [ $user_homedirectory_file_other_permission -eq 1 ] || [ $user_homedirectory_file_other_permission -eq 4 ] || [ $user_homedirectory_file_other_permission -eq 5 ]; then
							continue
						fi
						details+=("\"${user_homedirectory_file} 파일이 타사용자 쓰기 권한이 부여되어 있는 상태입니다.\"")
					else
						details+=("\"${user_homedirectory_file} 파일의 소유자가 해당 계정으로 지정되지 않은 상태입니다.\"")
					fi
				done
			done
			for user_homedirectory_path in "${user_homedirectory_paths}"
			do
				for user_homedirectory_file in ${user_homedirectory_path}/.bash*
				do
					user_homedirectory_file_owner=$(stat -c %U ${user_homedirectory_file})
					owner_compare=($(cat /etc/passwd | grep bash | grep ${user_homedirectory_path} | awk -F: '{print $1}'))
					user_homedirectory_file_other_permission=$(stat -c %03a ${user_homedirectory_file} | cut -c3)
					if [[ $user_homedirectory_file_owner -eq $owner_compare ]]; then
						if [ $user_homedirectory_file_other_permission -eq 0 ] || [ $user_homedirectory_file_other_permission -eq 1 ] || [ $user_homedirectory_file_other_permission -eq 4 ] || [ $user_homedirectory_file_other_permission -eq 5 ]; then
							continue
						fi
						solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 ${user_homedirectory_file} 파일의 타사용자 쓰기 권한을 제거하여 주시기 바랍니다.\"")
					else
						solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 ${user_homedirectory_file} 파일의 소유자가 해당 계정으로 지정하여 주시기 바랍니다.\"")
					fi
				done
			done
		fi
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_58() {
    echo "  {"
    echo "    \"Item\": \"U-58\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.19 홈디렉토리로 지정한 디렉토리의 존재 관리\","
    echo "    \"Description\": \"사용자 계정과 홈 디렉토리의 일치 여부 점검\","
    # echo "    \"Command\": \"find /home /root -mindepth 1 -maxdepth 2 -type d -exec sh -c 'grep -q ":$1:" /etc/passwd && ls -ald $1' sh {} \;\","
    echo "    \"Command\": \"cat /etc/passwd | grep bash; ls -ald /root/ /home/*/\","

    declare -a details
    declare -a solutions

    judg=0
    user_entries=($(awk -F: '/bash$/ {print $1 ":" $6}' /etc/passwd))
    
    for entry in "${user_entries[@]}"; do
        IFS=':' read -r username home_directory <<< "$entry"
        if [ ! -d "$home_directory" ]; then
            details+=("\"$username 계정의 홈 디렉토리($home_directory)가 존재하지 않는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $username 계정에 홈 디렉토리를 지정하여 주시기 바랍니다.\"")
            ((judg++))
        fi
    done

    if [ $judg -eq 0 ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"모든 계정이 홈 디렉토리가 존재하는 상태입니다.\""
        echo "    ]"
    fi

    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_59() {
    echo "  {"
    echo "    \"Item\": \"U-59\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"2. 파일 및 디렉토리 관리\","
    echo "    \"Sub_Category\": \"2.20 숨겨진 파일 및 디렉토리 검색 및 제거\","
    echo "    \"Description\": \"숨김 파일 및 디렉토리 내 의심스러운 파일 존재 여부 점검\","
    # echo "    \"Command\": \"find /home /root -mindepth 1 -maxdepth 2 -type d -exec sh -c 'grep -q ":$1:" /etc/passwd && ls -ald $1 .*' sh {} \;\","
    echo "    \"Command\": \"find /root/.* /home/*/.*\","

	if [ `find / -name '.*' -type f 2>/dev/null | wc -l` -gt 0 ]; then
		echo "    \"status\": \"[인터뷰]\","
		echo "    \"details\": ["
        echo "      \"로그인이 가능한 사용자 홈 디렉터리 내 숨겨지거나 불필요한 파일이 존재하는지 담당자 확인이 필요합니다.\""
        echo "    ]"
	elif [ `find / -name '.*' -type d 2>/dev/null | wc -l` -gt 0 ]; then
		echo "    \"status\": \"[인터뷰]\","
		echo "    \"details\": ["
        echo "      \"로그인이 가능한 사용자 홈 디렉터리 내 숨겨지거나 불필요한 파일이 존재하는지 담당자 확인이 필요합니다.\""
        echo "    ]"
	else
		echo "    \"status\": \"[양호]\","
		echo "    \"details\": ["
        echo "      \"불필요하거나 의심스러운 숨겨진 파일 및 디렉토리가 존재하지 않는 상태입니다.\""
        echo "    ]"
	fi
    
    echo "  },"  
} >> "$rf"

U_19() {
    echo "  {"
    echo "    \"Item\": \"U-19\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.1 Finger 서비스 비활성화\","
    echo "    \"Description\": \"finger 서비스 비활성화 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep finger\","
    
    declare -a details
    declare -a solutions

    if ! command -v finger &>/dev/null; then
		echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Finger\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
	fi

    if grep -qs "finger" /etc/inetd.conf || grep -qs "finger" /etc/xinetd.conf; then
        details+=("\"Finger 서비스가 활성화되어 있는 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 Finger 서비스를 비활성화하여 주시기 바랍니다.\"")
	fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_20() {
    echo "  {"
    echo "    \"Item\": \"U-20\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.2 Anonymous FTP 비활성화\","
    echo "    \"Description\": \"익명 FTP 접속 허용 여부 점검\","
    echo "    \"Command\": \"cat /etc/passwd | grep ftp\","

    declare -a details
    declare -a solutions

    if [ $(grep -q "^ftp:" /etc/passwd) ]; then
        if [ -f "/etc/proftpd/proftpd.conf" ]; then
            if grep -qE "^User|^UserAlias" /etc/proftpd/proftpd.conf; then
                details+=("\"proFTP 설정 파일에서 'User'또는 'UserAlias' 옵션이 활성화되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 proftpd.conf 파일에서 User 및 Useralias 항목을 주석처리 해주시기 바랍니다.\"")
            else
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"proFTP 설정 파일에서 anonymous 접속이 비활성화되어 있는 상태입니다.\""
                echo "    ]"
            fi
        fi
        if [ -f "/etc/vsftpd/vsftpd.conf" ]; then
            if grep -q "^anonymous_enable=NO" /etc/vsftpd/vsftpd.conf; then
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"vsFTP 설정 파일에서 anonymous 접속이 비활성화되어 있는 상태입니다.\""
                echo "    ]"
            else
                details+=("\"vsFTP 설정 파일에서 \\\"anonymous_enable\\\" 이 활성화되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 vsftpd.conf 파일에서 \\\"anonymous_enable\\\" 을 \\\"NO\\\"로 설정하여 주시기 바랍니다.\"")
            fi
        fi
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"FTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_21() {
    echo "  {"
    echo "    \"Item\": \"U-21\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.3 r계열 서비스 비활성화\","
    echo "    \"Description\": \"r-command 서비스 비활성화 여부 점검\","
    echo "    \"Command\": \"ls -al /etc/xinetd.d\","

    declare -a details
    declare -a solutions

    r_services=("rsh" "rlogin" "rexec")

    is_secure=true
    is_vulnerable=true

    for service in "${r_services[@]}"; do
        service_status=$(chkconfig --list | grep "$service" | awk '{print $5}')
        if [[ "$service_status" == "on" ]]; then
            details+=("\"$service 서비스가 활성화되어 있는 상태입니다.\"")
            if netstat -tuln | grep -q "$service"; then
                if $is_vulnerable; then
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $service 서비스를 비활성화하여 주시기 바랍니다.\"")
                    is_vulnerable=false
                fi
            fi
            is_secure=false
        else
            if $is_secure; then
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"r 커맨드 서비스가 비활성화되어 있는 상태입니다.\""
                echo "    ]"
                is_secure=false
            fi
        fi
    done
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_22() {
    echo "  {"
    echo "    \"Item\": \"U-22\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.4 crond 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"Cron 관련 파일의 권한 적절성 점검\","
    echo "    \"Command\": \"ls -al /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d\","

    declare -a details
    declare -a solutions

    CRON_FILES="/etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d"
    CROND_USER="root"
    CROND_GROUP="root"

    for file in $CRON_FILES; do
        if [ -e "$file" ]; then
            file_perms=$(stat -c "%a" "$file")
            owner=$(stat -c "%U" "$file")
            group=$(stat -c "%G" "$file")
            
            perms_correct=true
            read_perm="${file_perms:0:1}"
            write_perm="${file_perms:1:1}"
            execute_perm="${file_perms:2:1}"

            if [[ "$read_perm" -gt 6 ]]; then perms_correct=false; fi
            if [[ "$write_perm" -gt 4 ]]; then perms_correct=false; fi
            if [[ "$execute_perm" -gt 0 ]]; then perms_correct=false; fi

            if [[ "$perms_correct" == true && "$owner" == "$CROND_USER" && "$group" == "$CROND_GROUP" ]]; then
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"$file 의 권한이 $file_perms 이고, 소유자가 root로 설정되어 있는 상태입니다.\""
                echo "    ]"
            else
                if [[ "$perms_correct" == false ]]; then
                    details+=("\"$file 의 권한이 $file_perms 로 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 의 권한을 640(-rw-r-----) 이하로 설정하여 주시기 바랍니다.\"")
                fi
                if [[ "$owner" != "$CROND_USER" ]]; then
                    details+=("\"$file 의 소유자가 $owner 로 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 의 소유자를 root로 설정하여 주시기 바랍니다.\"")
                fi
            fi
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"Cron 관련 파일 또는 디렉터리가 존재하지 않습니다.\""
            echo "    ]"
        fi
    done
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_23() {
    echo "  {"
    echo "    \"Item\": \"U-23\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.5 DoS 공격에 취약한 서비스 비활성화\","
    echo "    \"Description\": \"사용하지 않는 DoS 공격에 취약한 서비스의 실행 여부 점검\","
    echo "    \"Command\": \"ls -al /etc/xinetd.d\","

    declare -a details
    declare -a solutions
    vulnerable_services=("echo" "discard" "daytime" "chargen")

    for service in "${vulnerable_services[@]}"; do
        if service $service status > /dev/null 2>&1; then
            details+=("\"$service 서비스가 실행 중인 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $service 서비스를 비활성화하여 주시기 바랍니다.\"")

            print_results details[@] solutions[@]

            
            echo "  },"  

            return 0
        fi
    done
    echo "    \"status\": \"[양호]\","
    echo "    \"details\": ["
    echo "      \"echo, discard, daytime, chargen 서비스가 비활성화되어 있는 상태입니다.\""
    echo "    ]"
    echo "  },"  
} >> "$rf"

U_24() {
    echo "  {"
    echo "    \"Item\": \"U-24\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.6 NFS 서비스 비활성화\","
    echo "    \"Description\": \"불필요한 NFS 서비스 사용여부 점검\","
    echo "    \"Command\": \"ps -ef | grep nfs\","

    declare -a details
    declare -a solutions

    declare -a nfs_services=("nfs" "rpc.statd" "rpc.lockd")
    active_services=()

    for service in "${nfs_services[@]}"; do
        if ps aux | grep -q "[${service:0:1}]${service:1}"; then
            active_services+=("$service")
        fi
    done

    if [ ${#active_services[@]} -gt 0 ]; then
        for service in "${active_services[@]}"; do
            details+=("\"$service 서비스가 활성화되어 있는 상태입니다.\"")
        done
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 해당 서비스를 비활성화하여 주시기 바랍니다.\"")
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"불필요한 NFS 서비스 관련 데몬이 비활성화 되어 있는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_25() {
    echo "  {"
    echo "    \"Item\": \"U-25\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.7 NFS 접근 통제\","
    echo "    \"Description\": \"NFS(Network File System) 사용 시 허가된 사용자만 접속할 수 있도록 접근 제한 설정 적용 여부 점검\","
    echo "    \"Command\": \"cat /etc/exports\","

    declare -a details
    declare -a solutions

    if rpm -q nfs-utils &>/dev/null; then
        nfs_config="/etc/exports"       
        if [ -f "$nfs_config" ]; then
            if grep -qE "^\s*[^#]+\s+\(/[^)]*\)\s*\([^\)]*sec=sys[ ,]*[^)]*no_?access[ ,]*\)" "$nfs_config"; then
                details+=("\"NFS 서버 설정 파일에 everyone 공유를 제한하지 않은 불필요한 NFS 서비스가 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 NFS 서버 설정 파일에서 everyone 공유를 제한하는 설정을 추가하고 서비스를 다시 시작하여 주시기 바랍니다.\"")
            else
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"NFS 서버 설정 파일에 불필요한 NFS 서비스가 비활성화 되어 있고, everyone 공유가 제한되어 있는 상태입니다.\""
                echo "    ]"
            fi
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"NFS 서버 설정 파일이 존재하지 않습니다.\""
            echo "    ]"
        fi
    else
        echo "    \"status\": \"[N/A]\","
        echo "    \"details\": ["
        echo "      \"NFS 서버가 설치되어 있지 않습니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_26() {
    echo "  {"
    echo "    \"Item\": \"U-26\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.8 automountd 제거\","
    echo "    \"Description\": \"automountd 서비스 데몬의 실행 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep auto\","

    declare -a details
    declare -a solutions

    am_chk=$(ps -ef | grep automount | grep -v grep | wc -l)

    if [ $am_chk -gt 0 ]; then
        details+=("\"automountd 서비스가 활성화되어 있는 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 automountd 서비스를 비활성화하여 주시기 바랍니다.\"")
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"automountd\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_27() {
    echo "  {"
    echo "    \"Item\": \"U-27\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.9 RPC 서비스 확인\","
    echo "    \"Description\": \"불필요한 RPC 서비스 실행 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep rpc\","

    declare -a details
    declare -a solutions

    file_list=$(ls -A /etc/xinetd.d)
    count=0

    rpc_services=("rpc.cmsd" "rpc.ttdbserverd" "sadmind" "rusersd" "walld" "sprayd" "rstatd" "rpc.nisd" "rexd" "rpc.pcnfsd" "rpc.statd" "rpc.ypupdated" "rpc.rquotad" "kcms_server" "cachefsd")

    for rpc_service in "${rpc_services[@]}"; do
        process=$(ps -ef | grep -E "\b${rpc_service}\b" | grep -v grep)
        if [ -n "$process" ]; then
            owner=$(echo "$process" | awk '{print $1}')
            if [ "$owner" != "root" ]; then
                details+=("\"불필요한 RPC 서비스($rpc_service)가 활성화되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 불필요한 RPC 서비스를 비활성화하여 주시기 바랍니다.\"")

                print_results details[@] solutions[@]

                
                echo "  },"  
                return 0
            fi
        fi
    done
    echo "    \"status\": \"[양호]\","
    echo "    \"details\": ["
    echo "      \"불필요한 RPC 서비스가 비활성화되어 있는 상태입니다.\""
    echo "    ]"

    
    echo "  },"  
} >> "$rf"

U_28() {
    echo "  {"
    echo "    \"Item\": \"U-28\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.10 NIS, NIS+ 점검\","
    echo "    \"Description\": \"불필요한 NIS 서비스 사용여부 점검\","
    echo "    \"Command\": \"ps -ef | grep \\\"ypserv\\\|ypbind\\\|ypxfrd\\\|rpc.yppasswdd\\\|rpc.ypupdated\\\"\","

    declare -a details
    declare -a solutions
    declare -a nis_services=("ypserv" "ypbind" "ypxfrd" "rpc.yppasswdd" "rpc.ypupdated")
    active_services=()

    for service in "${nis_services[@]}"; do
        if ps aux | grep "[${service:0:1}]${service:1}" | grep -v grep > /dev/null; then
            active_services+=("$service")
        fi
    done

    if [ ${#active_services[@]} -gt 0 ]; then
        for service in "${active_services[@]}"; do
            details+=("\"불필요한 NIS 서비스($service)가 활성화되어 있는 상태입니다.\"")
        done
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 불필요한 NIS 서비스를 비활성화하여 주시기 바랍니다.\"")
    else
	    echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"불필요한 NIS, NIS+ 서비스가 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_29() {
    echo "  {"
    echo "    \"Item\": \"U-29\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.11 tftp, talk 서비스 비활성화\","
    echo "    \"Description\": \"tftp, talk 등의 서비스를 사용하지 않거나 취약점이 발표된 서비스의 활성화 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep \\\"tftp\\\|talk\\\"\","

    declare -a details
    declare -a solutions
    services=("tftp" "talk" "ntalk")

    for service in "${services[@]}"; do
        ps_output=$(ps -ef | grep -v grep | grep "$service")
        if [ -n "$ps_output" ]; then
            details+=("\"$service 서비스가 활성화되어 있는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $service 서비스를 비활성화 해주시기 바랍니다.\"")

            print_results details[@] solutions[@]
            
            echo "  },"
            return 0
        fi
    done
    echo "    \"status\": \"[양호]\","
    echo "    \"details\": ["
    echo "      \"tftp, talk, ntalk 서비스가 모두 비활성화되어 있는 상태입니다.\""
    echo "    ]"
    echo "  },"
} >> "$rf"

U_30() {
    echo "  {"
    echo "    \"Item\": \"U-30\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.12 Sendmail 버전 관리\","
    echo "    \"Description\": \"Sendmail 버전과 실행 상태 점검\","
    echo "    \"Command\": \"rpm -qa | grep sendmail\","

    declare -a details
    declare -a solutions

    if ! pgrep -x "sendmail" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"SMTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        sendmailcf_files=$(find / -name 'sendmail.cf' -type f 2>/dev/null)
        if [[ -n "$sendmailcf_files" ]]; then
            for file in $sendmailcf_files; do
                version=$(grep -E '^#.*v.*' "$file" | awk '{print $NF}' | cut -d'/' -f1)
                if [[ "$version" > "8.15.2" ]]; then
                    echo "    \"status\": \"[양호]\","
                    echo "    \"details\": ["
                    echo "      \"Sendmail 버전이 최신 버전인 상태입니다.\""
                    echo "    ]"
                else
                    details+=("\"Sendmail 버전이 최신버전이 아닙니다: 현재 버전 $version.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 Sendmail 서비스를 최신 버전으로 업그레이드하여 주시기 바랍니다.\"")
                fi
            done
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"sendmail.cf 파일이 존재하지 않습니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_31() {
    echo "  {"
    echo "    \"Item\": \"U-31\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.13 스팸 메일 릴레이 제한\","
    echo "    \"Description\": \"SMTP 서버의 릴레이 기능 제한 여부 점검\","
    echo "    \"Command\": \"find / -name 'sendmail.cf' -type f\","

    declare -a details
    declare -a solutions

    ps_smtp_count=$(ps -ef | grep -iE 'smtp|sendmail' | grep -v 'grep' | wc -l)
    if [ $ps_smtp_count -eq 0 ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"SMTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        sendmailcf_files=$(find / -name 'sendmail.cf' -type f 2>/dev/null)
        if [[ -n "$sendmailcf_files" ]]; then
            relay_limits_set=false
            for file in $sendmailcf_files; do
                if grep -qE 'R$\*' "$file" && grep -qE 'Relaying denied' "$file"; then
                    relay_limits_set=true
                    break
                fi
            done
            if $relay_limits_set; then
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"SMTP 서비스에 릴레이 제한이 설정되어 있는 상태입니다.\""
                echo "    ]"
            else
                details+=("\"SMTP 서비스에 릴레이 제한이 설정되어 있지 않은 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 SMTP 서비스에 릴레이 제한을 설정하여 주시기 바랍니다.\"")
            fi
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"sendmail.cf 파일이 존재하지 않습니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_32() {
    echo "  {"
    echo "    \"Item\": \"U-32\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.14 일반사용자의 Sendmail 실행 방지\","
    echo "    \"Description\": \"SMTP 서비스 사용 시 일반사용자의 q 옵션 제한 여부 점검\","
    echo "    \"Command\": \"find / -name 'sendmail.cf' -type f -exec cat {} \\\;\","

    declare -a details
    declare -a solutions

    ps_smtp_count=$(ps -ef | grep -iE 'smtp|sendmail' | grep -v 'grep' | wc -l)
    if [ $ps_smtp_count -eq 0 ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"SMTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
        echo "  },"
        return 0
    else
        sendmailcf_files=$(find / -name 'sendmail.cf' -type f 2>/dev/null)
        if [[ -n "$sendmailcf_files" ]]; then
            for file in $sendmailcf_files; do
                restrictq=$(grep -vE '^#|^\s#' "$file" | awk '{gsub(" ", "", $0); print tolower($0)}' | awk -F 'q' '{print $2}' | grep -w 'r')
                if [[ -z "$restrictq" ]]; then
                    details+=("\"$file 파일에서 q 옵션 제한이 설정되어 있지 않은 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 일반 사용자의 Sendmail 실행 방지를 활성화하여 주시기 바랍니다.\"")
                    print_results details[@] solutions[@]
                    
                    echo "  },"
                    return 0
                fi
            done
        fi
    fi
    echo "    \"status\": \"[양호]\","
    echo "    \"details\": ["
    echo "      \"일반 사용자의 Sendmail 실행 방지가 활성화되어 있는 상태입니다.\""
    echo "    ]"
    echo "  },"
} >> "$rf"

U_33() {
    echo "  {"
    echo "    \"Item\": \"U-33\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.15 DNS 보안 버전 패치\","
    echo "    \"Description\": \"BIND 최신버전 사용 유무 및 주기적 보안 패치 여부 점검\","
    echo "    \"Command\": \"rpm -qa | grep bind\","

    declare -a details
    declare -a solutions

    if ! pgrep named >/dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"DNS\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        rpm_bind9_minor_version=$(rpm -qa 2>/dev/null | grep '^bind' | awk -F '9.' '{print $2}' | grep -v '^$' | uniq)
        if [ -n "$rpm_bind9_minor_version" ]; then
            bind_update_needed=false
            for version in $rpm_bind9_minor_version; do
                if [[ $version =~ 18.* ]]; then
                    rpm_bind9_patch_version=$(rpm -qa 2>/dev/null | grep '^bind' | awk -F '18.' '{print $2}' | grep -v '^$' | uniq)
                    if [ -n "$rpm_bind9_patch_version" ]; then
                        for patch_version in $rpm_bind9_patch_version; do
                            if ! [[ $patch_version =~ [7-9]* ]] || ! [[ $patch_version =~ 1[0-6]* ]]; then
                                bind_update_needed=true
                                break
                            fi
                        done
                    fi
                fi
            done

            if $bind_update_needed; then
                details+=("\"BIND 버전이 최신 버전이 아닌 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 BIND 버전을 최신 버전으로 설정하여 주시기 바랍니다.\"")
            else
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"BIND 버전이 최신 버전인 상태입니다.\""
                echo "    ]"
            fi
        fi
    fi
    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_34() {
    echo "  {"
    echo "    \"Item\": \"U-34\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.16 DNS Zone Transfer\","
    echo "    \"Description\": \"Secondary Name Server로만 Zone 정보 전송 제한 여부 점검\","
    echo "    \"Command\": \"cat /etc/named.conf\","

    declare -a details
    declare -a solutions

    if ! pgrep named >/dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"DNS\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        etc_namedconf_allowtransfer_count=$(grep -vE '^#|^\s#' /etc/named.conf | grep -i 'allow-transfer' | grep -i 'any' | wc -l)
        if [ "$etc_namedconf_allowtransfer_count" -gt 0 ]; then
            details+=("\"/etc/named.conf 파일에 allow-transfer { any; } 설정이 있는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 allow-transfer 옵션을 허가된 사용자에게만 활성화하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"허가되지 않는 사용자에게 Zone Transfer가 제한되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_35() {
    echo "  {"
    echo "    \"Item\": \"U-35\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.17 Apache 디렉토리 리스팅 제거\","
    echo "    \"Description\": \"디렉토리 검색 기능의 활성화 여부 점검\","
    echo "    \"Command\": \"cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    declare -a vulnerable_files
    declare -a details
    declare -a solutions

    # Apache 서비스 구동 여부 확인
    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\"데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        for file in "${cf[@]}"; do
            if sudo test -f "$file"; then
                # 실제로 적용된 'Indexes' 설정 확인
                if sudo grep -E "^\s*Options" "$file" | grep -E "Indexes" | grep -vE "^\s*#" > /dev/null; then
                    vulnerable_files+=("$file")
                fi
            fi
        done
        if [ ${#vulnerable_files[@]} -gt 0 ]; then
            for vf in "${vulnerable_files[@]}"; do
                details+=("\"$vf에 \\\"Indexes\\\" 옵션이 활성화되어 있는 상태입니다.\"")
            done
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 각 파일 옵션에 \\\"-Indexes\\\"로 설정하시거나 제거하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"Indexes 옵션이 비활성화되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_36(){

    echo "  {"
    echo "    \"Item\": \"U-36\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.18 Apache 웹 프로세스 권한 제한\","
    echo "    \"Description\": \"Apache 데몬이 root 권한으로 구동되는지 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep httpd; cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    declare -a vulnerable_files
    declare -a details
    declare -a solutions

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        for file in "${cf[@]}"; do
            if sudo test -f "$file"; then
                # User와 Group 설정 추출 및 확인
                user=$(sudo grep -E "^\s*User" "$file" | grep -v "#" | awk '{print $2}')
                group=$(sudo grep -E "^\s*Group" "$file" | grep -v "#" | awk '{print $2}')
                if [ "$user" == "root" ] || [ "$group" == "root" ]; then
                    vulnerable_files+=("$file")
                fi
            fi
        done
        if [ ${#vulnerable_files[@]} -gt 0 ]; then
            for vf in "${vulnerable_files[@]}"; do
                details+=("\"\\\"Apache\\\" 데몬이 root 계정으로 구동되고 있는 상태입니다.\"")
            done
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"Apache\\\" 데몬이 전용 계정으로 구동되도록 설정하여주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"\\\"Apache\\\"데몬이 전용 계정으로 구동되고 있으며, 설정 파일 내 사용자 계정과 그룹에 모두 동일하게 설정되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_37(){
    echo "  {"
    echo "    \"Item\": \"U-37\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.19 Apache 상위 디렉토리 접근 금지\","
    echo "    \"Description\": \"\\\"..\\\" 와 같은 문자 사용 등으로 상위 경로로 이동이 가능한지 여부 점검\","
    echo "    \"Command\": \"cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    declare -a vulnerable_files
    declare -a details
    declare -a solutions

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        for file in "${cf[@]}"; do
            if sudo test -f "$file"; then
                # AllowOverride 설정값 확인
                if sudo grep -E "^\s*AllowOverride" "$file" | grep -E "(None|AuthConfig|All)" | grep -vE "^\s*#" > /dev/null; then
                    vulnerable_files+=("$file")
                fi
            fi
        done
        if [ ${#vulnerable_files[@]} -gt 0 ]; then
            for vf in "${vulnerable_files[@]}"; do
                details+=("\"$vf에 상위 디렉토리 접근 제한이 설정되어 있지 않은 상태입니다.\"")
            done
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"AllowOverride\\\" 값을 \\\"AuthConfig\\\" 또는 \\\"All\\\"로 설정하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"상위 디렉토리 접근 제한이 적절하게 설정되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_38(){
    echo "  {"
    echo "    \"Item\": \"U-38\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.20 Apache 불필요한 파일 제거\","
    echo "    \"Description\": \"Apache 설치 시 기본으로 생성되는 불필요한 파일의 삭제 여부 점검\","
    echo "    \"Command\": \"find / -type f -name \\\"manual\\\" -o -name \\\"htdocs\\\"\","

    cf=("/etc/httpd/"* "/var/www/"*)

    declare -a vuln_files
    declare -a details
    declare -a solutions

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        # "manual" 또는 "htdocs" 이름을 가진 파일 또는 디렉토리 검사       
        while IFS= read -r line; do
            vuln_files+=("$line")
        done < <(find "${cf[@]}" -type f \( -name "manual" -o -name "htdocs" \) 2>/dev/null )

        if [ ${#vuln_files[@]} -gt 0 ]; then
            for vf in "${vuln_files[@]}"; do
                details+=("\"$vf 파일 또는 디렉터리가 존재하고 있는 상태입니다.\"")
            done
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $vf 파일 또는 디렉터리를 제거하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"Apache 설치 디렉터리 및 웹 Source 디렉터리 내 불필요한 파일이 존재하지 않는 상태입니다.\""
            echo "    ]"
        fi
    fi    
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_39(){
    echo "  {"
    echo "    \"Item\": \"U-39\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.21 Apache 링크 사용 금지\","
    echo "    \"Description\": \"심볼릭 링크, aliases 사용 제한 여부 점검\","
    echo "    \"Command\": \"cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    declare -a vulnerable_files
    declare -a details
    declare -a solutions

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        for file in "${cf[@]}"; do
            if sudo test -f "$file"; then
                # 실제로 적용된 'FollowSymLinks' 설정 확인
                if sudo grep -E "^\s*Options" "$file" | grep "FollowSymLinks" | grep -vE "^\s*#" > /dev/null; then
                    vulnerable_files+=("$file")
                fi
            fi
        done

        if [ ${#vulnerable_files[@]} -gt 0 ]; then
            for vf in "${vulnerable_files[@]}"; do
                details+=("\"$vf에 \\\"FollowSymLinks\\\" 옵션이 활성화되어 있는 상태입니다.\"")
            done
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 각 파일의 옵션에서 \\\"-FollowSymLinks\\\"로 설정하시거나 제거하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"FollowSymLinks 옵션이 비활성화되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_40(){
    echo "  {"
    echo "    \"Item\": \"U-40\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.22 Apache 파일 업로드 및 다운로드 제한\","
    echo "    \"Description\": \"파일 업로드 및 다운로드의 사이즈 제한 여부 점검\","
    echo "    \"Command\": \"cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    declare -a details
    declare -a solutions

    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        limit_set=false
        for file in "${cf[@]}"; do
            if sudo test -f "$file"; then
                # LimitRequestBody 설정 확인
                if sudo grep -E "^\s*LimitRequestBody" "$file" | grep -vE "^\s*#" > /dev/null; then
                    limit_value=$(sudo grep -E "^\s*LimitRequestBody" "$file" | grep -vE "^\s*#" | awk '{print $2}')
                    # 파일 업로드 및 다운로드 제한이 설정되어 있는지 확인
                    if [[ "$limit_value" != "" ]] && [[ "$limit_value" -gt 0 ]]; then
                        limit_set=true
                        echo "    \"status\": \"[양호]\","
                        echo "    \"details\": ["
                        echo "      \"전체 웹 Source 디렉터리에 업로드 및 다운로드 용량 제한이 설정되어 있는 상태입니다.\""
                        echo "    ]"
                        break
                    fi
                fi
            fi
        done
        if ! $limit_set; then
            details+=("\"$file 에 업로드 및 다운로드 용량 제한이 설정되어 있지 않은 상태입니다.\"")
            solutions+=("\"주요정보통신기반가이드를 참고하시어 웹 Source 디렉터리에 \\\"LimitRequestBody\\\"옵션을 설정하여 주시기 바랍니다.\"")
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_41(){
    echo "  {"
    echo "    \"Item\": \"U-41\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.23 Apache 웹 서비스 영역의 분리\","
    echo "    \"Description\": \"웹 서버의 루트 디렉토리와 OS의 루트 디렉토리를 다르게 지정하였는지 점검\","
    echo "    \"Command\": \"cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    declare -a details
    declare -a solutions

    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        document_root_set=false
        for file in "${cf[@]}"; do
            if sudo test -f "$file"; then
                while IFS= read -r line; do
                    document_root=$(echo "$line" | grep -oP '^DocumentRoot\s+"\K[^"]+')
                    if [[ -n "$document_root" ]] && { [[ "$document_root" == "/usr/local/apache/htdocs" ]] || [[ "$document_root" == "/usr/local/apache2/htdocs" ]] || [[ "$document_root" == "/var/www/html" ]]; }; then
                        details+=("\"$file 의 웹 Source 디렉터리가 기본 디렉터리($document_root)로 설정되어 있는 상태입니다.\"")
                        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 웹 Source 디렉터리를 유추할 수 없는 다른 경로로 설정하여 주시기 바랍니다.\"")
                        document_root_set=true
                        break 2
                    fi
                done < <(sudo grep "DocumentRoot" "$file" | grep -vE '^#')
            fi
        done
        if ! $document_root_set; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"모든 설정 파일에서 \\\"DocumentRoot\\\"가 별도의 디렉토리로 지정되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_60(){
    echo "  {"
    echo "    \"Item\": \"U-60\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.24 ssh 원격접속 허용\","
    echo "    \"Description\": \"원격 접속 시 SSH 프로토콜을 사용하는지 점검\","
    echo "    \"Command\": \"netstat -tlnp\","

    declare -a details
    declare -a solutions

    insecure_services=("telnet" "ftp")
    declare -a active_insecure_services

    # /etc/services 파일에서 서비스 이름을 기반으로 포트 번호 찾기
    for service_name in "${insecure_services[@]}"; do
        if pgrep -x "$service_name" > /dev/null; then
            # 서비스가 실행 중인 경우, 해당 서비스의 포트 번호를 /etc/services에서 찾기
            port=$(grep "^$service_name " /etc/services | awk '{print $2}' | sed 's#/.*##' | uniq)
            if [ -n "$port" ] && ss -tuln | grep -q ":$port "; then
                active_insecure_services+=("$service_name")
            fi
        fi
    done

    ssh_active=false
    if pgrep -x "sshd" > /dev/null; then
        ssh_active=true
    fi

    if $ssh_active && [ ${#active_insecure_services[@]} -eq 0 ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"원격 접속 시 SSH만 사용하도록 설정되어 있는 상태입니다.\""
        echo "    ]"
    else
        if [ ${#active_insecure_services[@]} -gt 0 ]; then
            for service in "${active_insecure_services[@]}"; do
                details+=("\"\\\"$service\\\" 서비스가 실행되고 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"$service\\\" 서비스를 중단하여 주시기 바랍니다.\"")
            done
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_61(){
    echo "  {"
    echo "    \"Item\": \"U-61\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.25 FTP 서비스 확인\","
    echo "    \"Description\": \"FTP 서비스가 활성화되어있는지 점검\","
    echo "    \"Command\": \"ps -ef | grep ftp\","

    declare -a details
    declare -a solutions
    service_name="ftp"

    port=$(grep "^$service_name " /etc/services | awk '{print $2}' | sed 's#/.*##' | uniq)

    if [ -n "$port" ]; then
        if ss -tuln | grep -q ":$port "; then
            details+=("\"FTP 서비스가 활성화되어 있는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"FTP\\\"서비스를 비활성화 하여 주시기 바랍니다.\"")
        else
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"\\\"FTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_62(){
    echo "  {"
    echo "    \"Item\": \"U-62\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.26 FTP 계정 shell 제한\","
    echo "    \"Description\": \"FTP 기본 계정에 쉘 설정 여부 점검\","
    echo "    \"Command\": \"cat /etc/passwd | grep ftp\","

    declare -a details
    declare -a solutions
    service_name="ftp"

    port=$(grep "^$service_name " /etc/services | awk '{print $2}' | sed 's#/.*##' | uniq)

    ftp_active=false
    if ss -tuln | grep -q ":$port "; then
        ftp_active=true
    fi

    if ! $ftp_active; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"FTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        ftp_shell=$(grep "^ftp:" /etc/passwd | cut -d: -f7)
        if [ "$ftp_shell" == "/usr/sbin/nologin" ] || [ "$ftp_shell" == "/bin/false" ]; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"\\\"FTP\\\" 기본 계정의 로그인이 불가능하게 설정되어 있는 상태입니다.\""
            echo "    ]"
        else
            details+=("\"\\\"FTP\\\" 기본 계정의 로그인이 가능하게 설정되어 있는 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 \\\"FTP\\\" 기본 계정의 로그인 쉘을 /bin/false 쉘로 설정하여 주시기 바랍니다.\"")
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_63(){
    echo "  {"
    echo "    \"Item\": \"U-63\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.27 FTP 접근제어 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"FTP 접근제어 설정파일에 관리자 외 비인가자들이 수정 제한 여부 점검\","
    echo "    \"Command\": \"ls -al /etc/ftpusers\","

    declare -a details
    declare -a solutions

    ftp_port=$(grep "^ftp " /etc/services | awk '{print $2}' | sed 's#/.*##' | uniq)

    if ! ss -tuln | grep -q ":$ftp_port " ; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"FTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        ftpusers_file="/etc/ftpusers"
        if [ -f "$ftpusers_file" ]; then
            file_owner=$(stat -c "%U" "$ftpusers_file")
            file_perms=$(stat -c "%a" "$ftpusers_file")
            
            if [ "$file_owner" != "root" ]; then
                echo "파일의 소유자가 $file_owner 로 설정되어 있는 상태입니다."
                echo "주요정보통신기반시설 가이드를 참고하시어 파일의 소유자를 root로 설정하여 주시기 바랍니다."
            else
                perms_correct=true
                read_perm="${file_perms:0:1}"
                write_perm="${file_perms:1:1}"
                execute_perm="${file_perms:2:1}"
                
                if [[ "$read_perm" -gt 6 ]]; then perms_correct=false; fi
                if [[ "$write_perm" -gt 4 ]]; then perms_correct=false; fi
                if [[ "$execute_perm" -gt 0 ]]; then perms_correct=false; fi
                
                if $perms_correct; then
                    echo "    \"status\": \"[양호]\","
                    echo "    \"details\": ["
                    echo "      \"ftpusers 파일 소유자가 root이고, 권한이 ${file_perms}으로 설정되어 있는 상태입니다.\""
                    echo "    ]"
                else
                    details+=("\"ftpusers 파일의 권한이 ${file_perms} 으로 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 파일의 권한을 640 이하로 설정하여 주시기 바랍니다.\"")
                fi
            fi
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"ftpusers 파일이 존재하지 않습니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_64(){
    echo "  {"
    echo "    \"Item\": \"U-64\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.28 FTP 접속 시 root 계정 차단\","
    echo "    \"Description\": \"FTP 서비스를 사용할 경우 ftpusers 파일 root 계정이 포함 여부 점검\","
    echo "    \"Command\": \"cat /etc/ftpusers\","

    declare -a details
    declare -a solutions

    ftp_port=$(grep "^ftp " /etc/services | awk '{print $2}' | sed 's#/.*##' | uniq)

    if ! ss -tuln | grep -q ":$ftp_port "; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"FTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        if grep -E "^ftp:" /etc/passwd | grep -E "(nologin|/bin/false)$"; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"FTP 기본 계정의 로그인이 불가능하게 설정되어 있는 상태입니다.\""
            echo "    ]"
        else
            ftpusers_file="/etc/ftpusers"
        
            if [ -f "$ftpusers_file" ]; then
                if grep -qw "^root$" "$ftpusers_file"; then
                    echo "    \"status\": \"[양호]\","
                    echo "    \"details\": ["
                    echo "      \"FTP 서비스 활성화 시 root 계정 접속이 차단되어 있는 상태입니다.\""
                    echo "    ]"
                else
                    details+=("\"FTP 서비스가 활성화되어 있고, root 계정 접속을 허용하도록 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 ftpusers 파일에 root 계정을 추가하여 주시기 바랍니다.\"")
                fi
            else
                echo "    \"status\": \"[N/A]\","
                echo "    \"details\": ["
                echo "      \"ftpusers 파일이 존재하지 않습니다.\""
                echo "    ]"
            fi
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_65(){
    echo "  {"
    echo "    \"Item\": \"U-65\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.29 AT 파일 소유자 및 권한 설정\","
    echo "    \"Description\": \"관리자(root)만 at.allow 파일과 at.deny 파일을 제어할 수 있는지 점검\","
    echo "    \"Command\": \"ls -al /etc/at.deny /etc/at.allow\","

    declare -a details
    declare -a solutions

    at_files=("/etc/at.allow" "/etc/at.deny")

    for file in "${at_files[@]}"; do
        if [ -f "$file" ]; then
            file_owner=$(stat -c "%U" "$file")
            file_perms=$(stat -c "%a" "$file")
            read_perm="${file_perms:0:1}"
            write_perm="${file_perms:1:1}"
            execute_perm="${file_perms:2:1}"

            if [ "$file_owner" != "root" ]; then
                details+=("\"$file 의 소유자가 $file_owner 로 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 의 소유자를 root로 설정하여 주시기 바랍니다.\"")
            elif [[ "$read_perm" -le 6 ]] && [[ "$write_perm" -le 4 ]] && [[ "$execute_perm" -le 0 ]]; then
                continue
            else
                details+=("\"$file 의 권한이 ${file_perms}으로 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $file 의 권한을 640(-rw-r-----) 이하로 설정하여 주시기 바랍니다.\"")
            fi
        fi
    done
    if [ ! -f "/etc/at.allow" ] && [ ! -f "/etc/at.deny" ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"root 만이 at 작업을 실행할 수 있도록 설정되어 있는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]
    echo "  },"  
} >> "$rf"

U_66(){
    echo "  {"
    echo "    \"Item\": \"U-66\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.30 SNMP 서비스 구동 점검\","
    echo "    \"Description\": \"SNMP 서비스 활성화 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep snmp\","

    declare -a details
    declare -a solutions

    snmp_daemons=("snmpd" "snmptrapd")

    snmp_active=false
    for daemon in "${snmp_daemons[@]}"; do
        if ps -a | grep -qw "$daemon"; then
            snmp_active=true
            break
        fi
    done

    if $snmp_active; then
        details+=("\"SNMP 서비스가 활성화되어 있는 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 SNMP 서비스를 비활성화하여 주시기 바랍니다.\"")
        solutions+=("\"부득이 해당 기능을 활용해야 하는 경우 기본 Community String 변경, 네트워크 모니터링 등의 보안 조치를 반드시 적용하여주시기 바랍니다.\"")
    else
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"SNMP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_67(){
    echo "  {"
    echo "    \"Item\": \"U-67\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.31 SNMP 서비스 Community String의 복잡성 설정\","
    echo "    \"Description\": \"SNMP Community String 복잡성 설정 여부 점검\","
    echo "    \"Command\": \"cat /etc/snmp/snmpd.conf\","

    declare -a details
    declare -a solutions

    snmp_daemons=("snmpd" "snmptrapd")

    snmp_active=false
    for daemon in "${snmp_daemons[@]}"; do
        if ps -a | grep -qw "$daemon"; then
            snmp_active=true
            break
        fi
    done

    if ! $snmp_active; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"SNMP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        while IFS= read -r conf_file; do
            grep -Eq "^\s*com2sec.*\s(public|private)\s" "$conf_file"
            if [ $? -eq 0 ]; then
                community_name=$(grep -Eo "(public|private)" "$conf_file" | uniq)
                details+=("\"SNMP community 이름이 $community_name 으로 설정되어 있는 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 해당 파일에서 커뮤니티명을 추측하기 어려운 값으로 변경하여 주시기 바랍니다.\"")
            fi
        done < <(find / -type f -name 'snmpd.conf' 2>/dev/null)
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_68(){
    echo "  {"
    echo "    \"Item\": \"U-68\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.32 로그온 시 경고 메시지 제공\","
    echo "    \"Description\": \"서버 및 서비스에 로그온 시 불필요한 정보 차단 설정 및 불법적인 사용에 대한 경고 메시지 출력 여부 점검\","
    echo "    \"Command\": \"ps -ef | grep \\\"telnet\\\|ftp\\\|sendmail\\\|named\\\"\","

    declare -a details
    declare -a solutions

    declare -A services=(
        [telnet]="/etc/issue.net"
        [ftp]="/etc/issue.net"
        [smtp]="/etc/mail/sendmail.cf"
        [dns]="/etc/issue.net"
    )

    declare -a active_services_without_warning
    all_services_inactive=true

    for service in "${!services[@]}"; do
        if pgrep -x "$service" > /dev/null; then
            all_services_inactive=false
            config_file=${services[$service]}
            if ! grep -q "Banner" "$config_file"; then
                active_services_without_warning+=("$service")
            fi
        fi
    done

    if $all_services_inactive; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Telnet, FTP, SMTP, DNS\\\" 데몬이 비활성화되어 있는 상태입니다\""
        echo "    ]"
    elif [ ${#active_services_without_warning[@]} -eq 0 ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"모든 서비스에 로그온 경고 메시지가 설정되어 있는 상태입니다.\""
        echo "    ]"
    else
        for service in "${active_services_without_warning[@]}"; do
            details+=("\"$service 서비스에 로그온 경고 메시지가 설정되어 있지 않은 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 $service 서비스에 로그온 경고 메시지를 설정하여 주시기 바랍니다.\"")
        done
        print_results details[@] solutions[@]
    fi

    
    echo "  },"
}  >> "$rf"

U_69(){
    echo "  {"
    echo "    \"Item\": \"U-69\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.33 NFS 설정파일 접근권한\","
    echo "    \"Description\": \"NFS 접근제어 설정파일에 대한 비인가자들의 수정 제한 여부 점검\","
    echo "    \"Command\": \"ls -al /etc/exports\","

    declare -a details
    declare -a solutions

    if ! ps -a | grep -qw "nfsd"; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"NFS\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        file="/etc/exports"
        if [ -f "$file" ]; then
            owner=$(stat -c "%U" "$file")
            perms=$(stat -c "%a" "$file")

            read_perms="${perms:0:1}"
            write_perms="${perms:1:1}"
            execute_perms="${perms:2:1}"

            if [[ "$owner" != "root" ]] || [[ "$read_perms" -gt 6 ]] || [[ "$write_perms" -gt 4 ]] || [[ "$execute_perms" -gt 4 ]]; then
                if [[ "$owner" != "root" ]]; then
                    details+=("\"NFS 접근제어 설정파일 소유자가 $owner 으로 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 NFS접근제어 설정파일의 소유자를 root로 변경하여 주시기 바랍니다.\"")
                fi
                if [[ "$read_perms" -gt 6 ]] || [[ "$write_perms" -gt 4 ]] || [[ "$execute_perms" -gt 4 ]]; then
                    details+=("\"NFS 접근제어 설정파일 권한이 $perms 로 설정되어 있는 상태입니다.\"")
                    solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 NFS접근제어 설정파일의 권한을 644(-rw-r--r--) 이하로 변경하여 주시기 바랍니다.\"")
                fi
            else
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"NFS 접근제어 설정파일 소유자가 root이고, 권한이 $perms 로 설정되어 있는 상태입니다.\""
                echo "    ]"
            fi
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"NFS 설정파일이 존재하지 않습니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_70(){
    echo "  {"
    echo "    \"Item\": \"U-70\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.34 expn, vrfy 명령어 제한\","
    echo "    \"Description\": \"SMTP 서비스 사용 시 vrfy, expn 명령어 사용 금지 설정 여부 점검\","
    echo "    \"Command\": \"cat /etc/mail/sendmail.cf\","

    declare -a details
    declare -a solutions

    if ! ps -a | grep -qw "sendmail"; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"SMTP\\\" 데몬이 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        sendmail_cf="/etc/mail/sendmail.cf"
        if [ -f "$sendmail_cf" ]; then
            privacy_options=$(grep "^O PrivacyOptions" "$sendmail_cf")
            if [[ "$privacy_options" == *"noexpn"* ]] && [[ "$privacy_options" == *"novrfy"* ]]; then
                echo "    \"status\": \"[양호]\","
                echo "    \"details\": ["
                echo "      \"SMTP 서비스 설정파일에 noexpn, novrfy 옵션이 설정되어 있는 상태입니다.\""
                echo "    ]"
            else
                details+=("\"SMTP 서비스 설정파일에 noexpn, novrfy 옵션이 설정되어 있지 않은 상태입니다.\"")
                solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 noexpn, novrfy 옵션을 설정하여 주시기 바랍니다.\"")
            fi
        else
            echo "    \"status\": \"[N/A]\","
            echo "    \"details\": ["
            echo "      \"SMTP 서비스 설정파일이 존재하지 않습니다.\""
            echo "    ]"
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"

U_71(){
    echo "  {"
    echo "    \"Item\": \"U-71\","
    echo "    \"Importance\": \"(중)\","
    echo "    \"Category\": \"3. 서비스 관리\","
    echo "    \"Sub_Category\": \"3.35 Apache 웹 서비스 정보 숨김\","
    echo "    \"Description\": \"웹페이지에서 오류 발생 시 출력되는 메시지 내용 점검\","
    echo "    \"Command\": \"cat /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf\","

    declare -a details
    declare -a solutions
    cf=("/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"*.conf)

    if ! pgrep -x "httpd" > /dev/null; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"\\\"Apache\\\" 데몬이  비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        server_tokens_status="Not Set"
        server_signature_status="Not Set"

        for file in "${cf[@]}"; do
            if [ -f "$file" ]; then
                st=$(grep -Ei "^\s*ServerTokens" "$file" | awk '{print $2}' | tail -1)
                server_tokens_status=${st:-$server_tokens_status}

                ss=$(grep -Ei "^\s*ServerSignature" "$file" | awk '{print $2}' | tail -1)
                server_signature_status=${ss:-$server_signature_status}
            fi
        done

        if [[ "$server_tokens_status" == "Prod" && "$server_signature_status" == "Off" ]]; then
            echo "    \"status\": \"[양호]\","
            echo "    \"details\": ["
            echo "      \"\\\"ServerTokens\\\" 값이 \\\"Prod\\\", \\\"ServerSignature\\\" 값이 \\\"Off\\\"로 적절히 설정되어 있는 상태입니다.\""
            echo "    ]"
        else
            details+=("\"\\\"ServerTokens\\\" 값이 \\\"$server_tokens_status\\\", \\\"ServerSignature\\\" 값이 \\\"$server_signature_status\\\"으로 설정되어 있는 상태입니다.\"")
            solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 \\\"ServerTokens\\\" 값을 \\\"Prod\\\", \\\"ServerSignature\\\" 값을 \\\"Off\\\"로 설정하여 주시기 바랍니다.\"")
        fi
    fi
    print_results details[@] solutions[@]

    
    echo "  },"  
} >> "$rf"


U_42() {
    echo "  {"
    echo "    \"Item\": \"U-42\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"4. 패치 관리\","
    echo "    \"Sub_Category\": \"4.1 최신 보안패치 및 벤더 권고사항 적용\","
    echo "    \"Description\": \"시스템에서 최신 패치가 적용되어 있는지 점검\","
    echo "    \"Command\": \"cat /etc/centos-release; rpm -qa | grep \\\"openssh\\\|bash\\\|glibc\\\|named\\\|openssl\\\"\","

    os_version_full=$(cat /etc/centos-release)
    os_version=$(echo "$os_version_full" | grep -oP 'release \K[0-9]+')

    declare -a details
    declare -a solutions

    if [[ "$os_version" -ge 7 ]]; then
        rpm=$(rpm -qa | grep "openssh\\\|bash\\\|glibc\\\|named\\\|openssl")
        rpm=$(echo "$rpm" | tr '\n' ' ')
        echo "    \"status\": \"[인터뷰]\","
        echo "    \"details\": ["
        echo "      \"$rpm \","
        echo "      \"패치 적용 정책을 수립하고 최신 패치를 적용하고 있는지 담당자 확인이 필요합니다.\""
        echo "    ]"
    else
        details+=("\"현재 사용하고 있는 $os_version_full 는 이미 EOS(End Of Service)가 되어 CVE 주요 취약점이 발생할 수 있는 패키지에 대한 패치작업을 진행할 수 없는 상태입니다.\"")
        solutions+=("\"주요정보통신기반시설 가이드를 참고하시어 주요 CVE 취약점 및 기타 취약점이 발생할 수 있는 패키지의 최신 패치 적용을 위해 OS를 상위 버전으로 신규 구축하여 주시기 바랍니다.\"")
        solutions+=("\"서비스 및 시스템 영향도를 파악하시어 설정 적용하시기 바랍니다.\"")
    fi
    print_results details[@] solutions[@]
    
    echo "  },"
} >> "$rf"

U_43() {
    echo "  {"
    echo "    \"Item\": \"U-43\","
    echo "    \"Importance\": \"(상)\","
    echo "    \"Category\": \"5. 로그 관리\","
    echo "    \"Sub_Category\": \"5.1 로그의 정기적 검토 및 보고\","
    echo "    \"Description\": \"로그의 정기적 검토 및 보고 여부 점검\","
    echo "    \"Command\": \"\","
    
    echo "    \"status\": \"[인터뷰]\","
    echo "    \"details\": ["
    echo "      \"시스템 로그의 최소 저장 기간 기준(6개월 이상) 유/무, 별도 저장 공간 내 보관 유/무, 보관된 로그에 대한 정기적인 감사 및 리포팅 유/무, 별도 보관된 로그 변경 가능성 유/무에 대한 담당자 확인이 필요합니다.\""
    echo "    ]"
    echo "  },"
} >> "$rf"


U_72() {
    echo "  {"
    echo "    \"Item\": \"U-72\","
    echo "    \"Importance\": \"(하)\","
    echo "    \"Category\": \"5. 로그 관리\","
    echo "    \"Sub_Category\": \"5.2 정책에 따른 시스템 로깅 설정\","
    echo "    \"Description\": \"내부 정책에 따른 시스템 로깅 설정 적용 여부 점검\","
    echo "    \"Command\": \"cat /etc/rsyslog.conf; ls -al /var/log/messages* /var/log/secure* /var/log/maillog* /var/log/cron*\","

    rsyslog_conf="/etc/rsyslog.conf"

    patterns=(
        "*.info;mail.none;authpriv.none;cron.none /var/log/messages"
        "authpriv.* /var/log/secure"
        "mail.* -/var/log/maillog"
        "cron.* /var/log/cron"
        "*.emerg *"
    )

    if [ `ps -ef | grep 'syslog' | grep -v 'grep' | wc -l` -eq 0 ]; then
        echo "    \"status\": \"[양호]\","
        echo "    \"details\": ["
        echo "      \"syslog 서비스가 비활성화되어 있는 상태입니다.\""
        echo "    ]"
    else
        if [ -f "$rsyslog_conf" ]; then
            for expected_pattern in "${patterns[@]}"; do
                if ! grep -Fq "$expected_pattern" "$rsyslog_conf"; then
                    no_patterns+=("$expected_pattern")
                fi
            done
            if [ -z "$no_patterns" ]; then
                echo "    \"status\": \"[인터뷰]\","
                echo "    \"details\": ["
                echo "      \"/etc/rsyslog.conf 파일이 로그 기록 정책이 내부 보안정책에 따라 설정되어 수립되어 있으며 로그를 남기고 있는지 담당자 확인이 필요합니다.\""
                echo "    ]"
            else
                details+=("\"/etc/rsyslog.conf 파일에 설정 내용이 존재하지 않는 상태입니다.\"")
                solutions+=("\"주요통신기반시설 가이드를 참고하시어 내부 보안정책에 따라 /etc/rsyslog.conf 파일을 설정하여 주시기 바랍니다.\"")
            fi
        else
            details+=("\"/etc/rsyslog.conf 파일이 존재하지 않는 상태입니다.\"")
            solutions+=("\"주요통신기반시설 가이드를 참고하시어 내부 보안정책에 따라 /etc/rsyslog.conf 파일을 설정하여 주시기 바랍니다.\"")
        fi
    fi
    print_results details[@] solutions[@]
    
    echo "  }" # 마지막 항목
} >> "$rf"


# 항목 함수 실행
U_01
U_02
U_03
U_04
U_44
U_45
U_46
U_47
U_48
U_49
U_50
U_51
U_52
U_53
U_54

U_05
U_06
U_07
U_08
U_09
U_10
U_11
U_12
U_13
U_14
U_15
U_16
U_17
U_18
U_55
U_56
U_57
U_58
U_59

U_19
U_20
U_21
U_22
U_23
U_24
U_25
U_26
U_27
U_28
U_29
U_30
U_31
U_32
U_33
U_34
U_35
U_36
U_37
U_38
U_39
U_40
U_41
U_60
U_61
U_62
U_63
U_64
U_65
U_66
U_67
U_68
U_69
U_70
U_71

U_42
U_43

U_72

# JSON 구조 닫기
{
    echo "  ]" # 체크결과 배열 종료
    echo "}" # 전체 JSON 종료
} >> "$rf"
