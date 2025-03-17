# Install build dependencies for Ubuntu
package %w(gcc make zlib1g-dev libpcre3-dev libssl-dev)

git '/tmp/nginx-source' do
  repository 'https://github.com/nginx/nginx.git'
  revision node['source_branch']
  action :checkout
end

execute 'build_nginx' do
  cwd '/tmp/nginx-source'
  command './auto/configure --prefix=/usr/local/nginx && make && make install'
  creates '/usr/local/nginx/sbin/nginx'
end

template '/etc/systemd/system/nginx.service' do
  source 'nginx.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
end

directory '/usr/local/nginx/html' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end