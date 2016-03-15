$myusers = hiera('users')
create_resources(user, $myusers)

$my_auth_keys = hiera ('auth_keys')
create_resources(ssh_authorized_key, $my_auth_keys)

