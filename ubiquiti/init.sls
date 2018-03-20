{% from "ubiquiti/envmap.jinja" import env_config as config with context %}

{% set controller_version = config['unifi_controller']['current_version'] %}
{% set unifi_address = config['unifi_address'] %}
{% set unifi_port = config['unifi_port'] %}
{% set unifi_access_webui_username = config['unifi_controller']['webui_username']['exporter_access'] %}

{% set unifi_home = salt.pillar.get('uids:unifi:home', '/opt/unifi') %}

include:
  - java

unifi:
  group.present:
    - gid: {{ pillar['uids']['unifi']['gid'] }}
  user.present:
    - uid: {{ pillar['uids']['unifi']['uid'] }}
    - gid: {{ pillar['uids']['unifi']['gid'] }}
    - home: {{ unifi_home }}
    - shell: /bin/false
    - createhome: False
    - require:
      - group: unifi
  service.running:
    - watch:
      - pkg: ubiquiti-controller-install
    - require:
      - pkg: ubiquiti-controller-install

ubiquiti-controller-install-debconf:
  debconf.set:
    - name: unifi
    - data:
        'unifi/has_backup': {'type': 'boolean', 'value': 'true'} 
ubiquiti-controller-install:
  pkg.installed:
    - name: unifi
    - require:
      - debconf: ubiquiti-controller-install-debconf
      - user: unifi


# unifi exporter

unifi-exporter:
  file.managed:
    - name: /usr/local/bin/unifi_exporter
    - source: s3://salt-prod/unifi/unifi_exporter
    - source_hash: md5=2046bcf72099c73a1d68032ad3f203ef 
    - user: unifi
    - group: unifi
    - mode: 0755
    - require:
      - user: unifi
      - service: unifi

unifi-exporter-init:
  file.managed:
    - name: /etc/init/unifi-exporter.conf
    - source: salt://ubiquiti/conf/etc/init/unifi-exporter.conf
    - template: jinja
    - defaults:
        server_bin: /usr/local/bin/unifi_exporter
        config_file: /etc/unifi_exporter.yml 
  service.running:
    - name: unifi-exporter
    - enable: true
    - require: 
      - file: unifi-exporter-init
      - file: unifi-exporter-config
   
unifi-exporter-config:
  file.managed:
    - name: /etc/unifi_exporter.yml
    - source: salt://ubiquiti/conf/etc/unifi_exporter.yml
    - template: jinja
    - defaults:
        listening_port: 9130 
        unifi_address: {{ unifi_address }}
        unifi_port: {{ unifi_port }}
        username: {{ unifi_access_webui_username }}
        site: SFO-Office

#syslog stuff
unifi-controller-rsyslog:
  file.managed:
    - name: /etc/rsyslog.d/ubiquiti.conf
    - source: salt://ubiquiti/conf/etc/rsyslog.d/ubiquiti.conf
    - template: jinja
    - defaults:
       mongod_file_location: /var/log/unifi/mongod.log
       mongod_tag: unificontroller
       mongod_state_file: unifi_mongodb_log
       mongod_facility: local0
       mongod_severity: info 
       server_file_location: /var/log/unifi/server.log
       server_tag: unificontroller 
       server_state_file: unifi_server_log
       server_facility: local0
       server_severity: info
       logtrust_relay_fqdn: logtrust-101.soma.plos.org
       logtrust_relay_port: 13006


#change permission of the unifi server logs
unifi-server-logs:
  file.managed:
    - name: /var/log/unifi/server.log
    - mode: 0640
    - replace: False
    
unifi-mongod-logs:
  file.managed:
    - name: /var/log/unifi/mongod.log
    - mode: 0640
    - replace: False

# add syslog user to the unifi group
extend:
  syslog:
    user.present:
      - optional_groups: [ unifi ] 
      - remove_groups: False 

