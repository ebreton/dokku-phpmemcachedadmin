DOKKU_HOST:=breton.ch
DOKKU_LETSENCRYPT_EMAIL:=manu@ibimus.com
DOKKU_MARIADB_SERVICE:=mysql

LOCAL_BACKUP_PATH:=~/var/dokku_backup

###
# ONE OFF

init-host:	
	# set email to use for let's encrypt globally
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
	ssh -t dokku@${DOKKU_HOST} config:set --global DOKKU_LETSENCRYPT_EMAIL=${DOKKU_LETSENCRYPT_EMAIL}
	# setup MariaDB
	# ! requires: sudo dokku plugin:install https://github.com/dokku/dokku-mariadb.git
	ssh -t dokku@${DOKKU_HOST} mariadb:create ${DOKKU_MARIADB_SERVICE} || true
	# pull initial docker image for Wordpress
	ssh -t ${DOKKU_HOST} docker pull phpmyadmin/phpmyadmin:latest


###
# CREATE & DESTROY

create: validate-app
	# and tag official image with our app name
	ssh -t ${DOKKU_HOST} docker tag phpmyadmin/phpmyadmin:latest dokku/${NAME}:latest
	# create an app and set environment variable+port before 1st deployment
	ssh -t dokku@${DOKKU_HOST} apps:create ${NAME}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} PMA_ABSOLUTE_URI=https://${NAME}.${DOKKU_HOST}
	ssh -t dokku@${DOKKU_HOST} config:set ${NAME} PMA_ARBITRARY=1
	# link with DB
	ssh -t dokku@${DOKKU_HOST} mariadb:link ${DOKKU_MARIADB_SERVICE} ${NAME}
	# trigger deployment on host
	ssh -t dokku@${DOKKU_HOST} tags:deploy ${NAME} latest
	# switch to HTTPs
	ssh -t dokku@${DOKKU_HOST} letsencrypt ${NAME}
	# remove unnecessary port
	ssh -t dokku@${DOKKU_HOST} proxy:ports-remove ${NAME} http:9000:9000

destroy: validate-app
	ssh -t dokku@${DOKKU_HOST} apps:destroy ${NAME}


###
# MONITORING

apps:
	ssh -t dokku@${DOKKU_HOST} apps:report ${NAME}

domains:
	ssh -t dokku@${DOKKU_HOST} domains:report ${NAME}

proxy:
	ssh -t dokku@${DOKKU_HOST} proxy:report ${NAME}

storage:
	ssh -t dokku@${DOKKU_HOST} storage:report ${NAME}

config: validate-app
	ssh -t dokku@${DOKKU_HOST} config ${NAME}


###
# BACKUP & RESTORE

backup-all:
	[ -d $(LOCAL_BACKUP_PATH) ] || mkdir -p $(LOCAL_BACKUP_PATH)
	rsync -av ${DOKKU_HOST}:/var/lib/dokku/data/storage/ ${LOCAL_BACKUP_PATH}

backup: validate-app
	[ -d $(LOCAL_BACKUP_PATH) ] || mkdir -p $(LOCAL_BACKUP_PATH)
	rsync -av ${DOKKU_HOST}:/var/lib/dokku/data/storage/${NAME} ${LOCAL_BACKUP_PATH}/

restore: validate-app
	rsync -av ${LOCAL_BACKUP_PATH}/${NAME} ${DOKKU_HOST}:/var/lib/dokku/data/storage/


###
# INPUT VALIDATION

validate-app:
ifndef NAME
	$(error NAME is not set)
endif
