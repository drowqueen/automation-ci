include_recipe 'apt'

package 'nginx' do
  version node['nginx_version']
  action :install
end