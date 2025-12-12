#!/usr/bin/env python3
"""
YAML 配置文件解析器
用于 iptables-docker 防火墙脚本

输出格式：每行一条规则，用 | 分隔字段
"""

import yaml
import sys
import os

def parse_yaml_config(yaml_file):
    """解析 YAML 配置文件并输出标准格式"""
    
    try:
        with open(yaml_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        
        if not config:
            print("WARNING: 配置文件为空", file=sys.stderr)
            return
        
        # 解析 allow-ports 规则
        if 'allow-ports' in config and config['allow-ports']:
            for rule in config['allow-ports']:
                port = rule.get('port')
                proto = rule.get('proto', 'tcp')
                sources = rule.get('sources', ['0.0.0.0/0'])
                desc = rule.get('description', '').replace(' ', '_').replace('|', '_')
                
                if not port:
                    continue
                
                for source in sources:
                    # 移除注释（# 后面的内容）
                    source = source.split('#')[0].strip()
                    if source:
                        print(f"ALLOW_PORT|{port}|{proto}|{source}|{desc}")
        
        # 解析 allow-sources 规则
        if 'allow-sources' in config and config['allow-sources']:
            for rule in config['allow-sources']:
                ip = rule.get('ip')
                desc = rule.get('description', '').replace(' ', '_').replace('|', '_')
                
                if ip:
                    ip = ip.split('#')[0].strip()
                    print(f"ALLOW_SOURCE|{ip}|{desc}")
        
        # 解析 docker-ports 规则
        if 'docker-ports' in config and config['docker-ports']:
            for rule in config['docker-ports']:
                port = rule.get('port')
                proto = rule.get('proto', 'tcp')
                sources = rule.get('sources', ['0.0.0.0/0'])
                desc = rule.get('description', '').replace(' ', '_').replace('|', '_')
                
                if not port:
                    continue
                
                for source in sources:
                    source = source.split('#')[0].strip()
                    if source:
                        print(f"ALLOW_CONTAINER_PORT|{port}|{proto}|{source}|{desc}")
        
        # 解析 forward-ports 规则
        if 'forward-ports' in config and config['forward-ports']:
            for rule in config['forward-ports']:
                ext_port = rule.get('external')
                int_ip = rule.get('internal-ip')
                int_port = rule.get('internal-port')
                proto = rule.get('proto', 'tcp')
                desc = rule.get('description', '').replace(' ', '_').replace('|', '_')
                
                if ext_port and int_ip and int_port:
                    print(f"FORWARD_PORT|{ext_port}|{int_ip}|{int_port}|{proto}|{desc}")
    
    except FileNotFoundError:
        print(f"ERROR: 配置文件不存在: {yaml_file}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"ERROR: YAML 解析错误: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    if len(sys.argv) != 2:
        print("用法: parse_yaml.py <yaml_config_file>", file=sys.stderr)
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    parse_yaml_config(yaml_file)

if __name__ == '__main__':
    main()