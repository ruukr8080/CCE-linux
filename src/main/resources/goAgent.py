import tkinter as tk
from tkinter import messagebox
import paramiko
import time
import json
import os

def get_resource_path(file_name):
    # 절대 경로를 직접 설정
    return os.path.join(r'C:\개인\projects\kosapro\src\main\resources', file_name)

def start_agent():
    username = entry_username.get()
    password = entry_password.get()
    port = int(entry_port.get())
    ip_address = entry_ip.get()

    # CentOS6.sh 및 result.json 파일 경로
    centos_script_path = get_resource_path('CentOS6.sh')
    result_json_path = get_resource_path('result.json')

    print(f"CentOS6.sh path: {centos_script_path}")
    print(f"result.json path: {result_json_path}")

    if not os.path.exists(centos_script_path):
        raise FileNotFoundError(f"File not found: {centos_script_path}")

    try:
        # Paramiko SSH 클라이언트 생성
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip_address, port=port, username=username, password=password)

        # SFTP 클라이언트 초기화
        sftp = ssh.open_sftp()
        sftp.put(centos_script_path, "agent.sh")

        # 명령 실행
        channel = ssh.invoke_shell()
        channel.send('cd ~\n')
        channel.send('sudo bash agent.sh\n')
        while not channel.recv_ready():
            time.sleep(0.1)
        channel.send(password + '\n')
        time.sleep(20)
        while not channel.recv_ready():
            time.sleep(0.1)

        # JSON 파일 다운로드
        sftp.get("result.json", result_json_path)

        if not os.path.exists(result_json_path):
            raise FileNotFoundError(f"{result_json_path} does not exist.")
        print(f"JSON file successfully downloaded to: {result_json_path}")

        # Cleanup
        channel.send('rm agent.sh\n')
        channel.send('rm result.json\n')
        time.sleep(2)
        channel.send('y\n')

        sftp.close()
        ssh.close()

        jsonfile_rename()
        messagebox.showinfo("Success", "Agent works successfully!")
    except Exception as e:
        messagebox.showerror("Error", str(e))

def on_destroy():
    messagebox.showinfo("Stop", "Agent was done!")
    root.destroy()  # 이벤트 루프 종료 및 모든 Tkinter 객체 제거

def jsonfile_rename():
    # JSON 파일 경로
    file_path = get_resource_path('result.json')

    if not os.path.exists(file_path):
        raise FileNotFoundError(f"{file_path} does not exist.")

    with open(file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)

    # 'Server_Info' 값 가져오기
    server_info = data.get('Server_Info', 'Server_Info not found')
    if server_info == 'Server_Info not found':
        raise ValueError("Server_Info not found in JSON data")

    new_file_path = get_resource_path(f'result_{server_info["UNIQ_ID"]}.json')

    # 파일 이름 변경
    os.rename(file_path, new_file_path)

# GUI 설정
