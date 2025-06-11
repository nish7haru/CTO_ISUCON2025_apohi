SSH_PRIVATE_KEY_PATH = ~/.ssh/isucon-14-kyo
REMOTE = ec2-57-180-137-236.ap-northeast-1.compute.amazonaws.com
SYSTEM_USER = isucon

ssh_login:
	ssh -i ${SSH_PRIVATE_KEY_PATH} ${SYSTEM_USER}@${REMOTE}
scp_sshkey_to_remote:
	scp -i ${SSH_PRIVATE_KEY_PATH} ~/.ssh/isucon-14-kyo ${SYSTEM_USER}@${REMOTE}:~/.ssh/
mv_sshkey_to_isucon_from_ubuntu:
	ssh -i ${SSH_PRIVATE_KEY_PATH} ${SYSTEM_USER}@${REMOTE} "sudo mv .ssh/isucon-14-kyo /home/isucon/.ssh/ && sudo chown isucon:isucon /home/isucon/.ssh/isucon-14-kyo"

# .ssh/config に
# Host github.com
#   Hostname github.com
#   User git
#   IdentityFile ~/.ssh/isucon-14-kyo

#####################################################################################################

# -----
# リモートで実行するコマンド（一回のみ）
# -----

# etc配下の設定ファイルをgit管理する
init_copy_etc:
	mkdir -p ./etc/mysql && cp /etc/mysql/my.cnf ./etc/mysql/my.cnf
	mkdir -p ./etc/nginx && cp /etc/nginx/nginx.conf ./etc/nginx/nginx.conf
	cp /etc/hosts ./etc/hosts
init_copy_app:
	mkdir -p ./webapp/go && cp -r ~/webapp/go ./webapp/go
	mkdir -p ./webapp/sql && cp -r ~/webapp/sql ./webapp/sql
	cp ~/webapp/openapi.yaml ./webapp/openapi.yaml
	mkdir -p ./webapp/payment_mock && cp -r ~/webapp/payment_mock ./webapp/payment_mock

#####################################################################################################

# etc配下の設定ファイルを変更したらcpで移動
copy_etc:
	sudo cp ./etc/mysql/my.cnf /etc/mysql/my.cnf
	sudo cp ./etc/nginx/nginx.conf /etc/nginx/nginx.conf
	sudo cp ./etc/hosts /etc/hosts

copy_app:
	sudo cp -rf ./webapp/go ~/webapp
	sudo cp -rf ./webapp/sql ~/webapp/sql
	sudo cp -rf ./webapp/ ~/webapp/openapi.yaml
	sudo cp -rf ./webapp/payment_mock ~/webapp/payment_mock

#####################################################################################################

# goのファイルをbuildして実行パスに移動


#####################################################################################################

restart_go:
	sudo systemctl restart isuride-go.service
restart_mysql:
	sudo systemctl restart mysql
restart_nginx:
	sudo systemctl restart nginx
restart_all: restart_go restart_mysql restart_nginx

#####################################################################################################

delete_access_log:
	echo -n > /var/log/nginx/access.log
BENCH_CMD=cd ~/bench && ./bench -all-addresses 127.0.0.11 -target 127.0.0.11:443 -tls -jia-service-url http://127.0.0.1:4999
bench: delete_access_log
	${BENCH_CMD}

#####################################################################################################

SERVICE_NAME=isuride

pull:
	git pull
build:
	cd ~/webapp/go && go build -o ${SERVICE_NAME}
deploy: pull build restart_all bench

#####################################################################################################

ALPSORT=sum
ALPM="/api/app/nearby-chairs\?.+,/api/owner/sales\?.+,/api/app/rides/[A-Z0-9]+/evaluation,/api/chair/rides/[A-Z0-9]+/status,/api/chair/rides/[A-Z0-9]+/evaluation,/images/.+,/assets/.+"
OUTFORMAT=count,method,uri,min,max,sum,avg,p99
alp:
	sudo alp ltsv --file=/var/log/nginx/access.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q
alpsave:
	sudo alp ltsv --file=/var/log/nginx/access.log --pos /tmp/alp.pos --dump /tmp/alp.dump --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q
alpload:
	sudo alp ltsv --load /tmp/alp.dump --sort $(ALPSORT) --reverse -o count,method,uri,min,max,sum,avg,p99 -q

# wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.zip
# unzip alp_linux_amd64.zip
# sudo install ./alp /usr/local/bin/alp

#####################################################################################################

pprof:
	go tool pprof -http=0.0.0.0:8090 ~/webapp/go/isupipe http://localhost:6060/debug/pprof/profile

#####################################################################################################

# mydql関連
MYSQL_HOST="127.0.0.1"
MYSQL_PORT=3306
MYSQL_USER=isucon
MYSQL_DBNAME=isuride
MYSQL_PASS=isucon
MYSQL=mysql -h$(MYSQL_HOST) -P$(MYSQL_PORT) -u$(MYSQL_USER) -p$(MYSQL_PASS) $(MYSQL_DBNAME)
SLOW_LOG=/var/lib/mysql/ip-192-168-0-11-slow.log

access_mysql:
	$(MYSQL)

delete_slow_log:
	echo -n > $(SLOW_LOG)
# DBを再起動すると設定はリセットされる
slow-on:delete_slow_log
	sudo systemctl daemon-reload
	sudo systemctl restart mysql
	sudo $(MYSQL) -e "set global slow_query_log_file = '$(SLOW_LOG)'; set global long_query_time = 0.001; set global slow_query_log = ON;"
slow-off:
	$(MYSQL) -e "set global slow_query_log = OFF;"
# mysqldumpslowを使ってslow wuery logを出力
slow-show:
	sudo mysqldumpslow -s t $(SLOW_LOG) | head -n 20