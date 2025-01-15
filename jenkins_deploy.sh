#! /bin/bash

function check_jenkins_container() {
	#echo "$(docker images | awk '{if($1 == "jenkins/jenkins"){print $1":"$2}}')"
	if [[ "$(docker images | awk '{if($1 == "jenkins/jenkins"){print $1":"$2}}')" == "jenkins/jenkins:latest" ]];then
		return 0
	else
		return 1
	fi
}

function check_docker() {
	if command -v docker >/dev/null 2>&1 ; then
		return 0
	else
		return 1
	fi
}

function install_docker() {
	if apt update && docker install -y docker.io;then
		return 0
	else
		return 1
	fi
}

function download_jenkins() {
	if docker pull jenkins/jenkins:latest;then
		return 0
	else
		return 1
	fi
	
}

function check_user_jenkins() {
	if id jenkins;then
		return 0
	else
		return 1
	fi
}


function run_jenkins() {
	echo "checking docker..."
	if ! check_docker;then
		echo "install docker..."
		if ! install_docker;then
			echo install docker failed, please install docker manually
			exit 1
		fi
		# 安装jenkins容器
		echo download jenkins container
		if ! download_jenkins;then
			echo download jenkins container failed, please download jenkins/jenkins:latest manually
			exit 1
		fi
	else
		echo "checking jenkins container..."
		check_jenkins_container
		if [[ $? != 0 ]];then
			echo download jenkins container
			if ! download_jenkins;then
				echo download jenkins container failed, please download jenkins/jenkins:latest manually
				exit 1
			fi
		fi
	fi

	# 重新检测jenkins容器是否安装成功
	if ! check_jenkins_container;then
		echo please install jenkins/jenkins:latest manually
		exit 1
	fi

	# 检测是否有jenkins用户
	if ! check_user_jenkins;then
		echo adding jenkins user...
		echo please input jenkins password: 
		read password
		echo "${password}\n${password}\n \n \n \n \n \ny\n" | adduser jenkins
		usermod -aG docker jenkins
		echo jenkins has be creatored
	fi

	# 启动jenkins容器
	
	if docker ps | grep jenkins_master >/dev/null 2>&1;then
		echo jenkins container is running, do you want to restart it?
		echo "1) yes 2) no"
		read flag
		if [[ ${flag} == 1 ]];then
			docker rm -f jenkins_master
		elif [[ ${flag} == 2 ]];then
			exit 0
		else
			echo "please select from [1, 2]"
			exit 1
		fi
	fi

	if docker ps -a |grep jenkins_master >/dev/null 2>&1;then
		if ! docker rm -f $(docker ps -a | grep jenkins_master | awk '{print $1}') >/dev/null 2>&1;then
			echo unexpected error occurred
			exit 1
		fi
	fi
	
	docker  run -d -p 8080:8080 \
		--restart always \
		-u $(id --user jenkins):$(id --group jenkins) \
		-v /home/jenkins:/var/jenkins_home \
		-v /etc/localtime:/etc/localtime \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /usr/bin/docker:/usr/bin/docker \
		--group-add $(getent group docker | awk -F: '{print $3}') \
		--name jenkins_master \
		jenkins/jenkins:latest
}

if ! run_jenkins;then
	echo jenkins container runs failed
else
	echo jenkins container runs successfully
fi
