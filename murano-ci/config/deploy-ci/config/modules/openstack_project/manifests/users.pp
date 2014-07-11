class openstack_project::users {
  @user::virtual::localuser { 'ci':
    realname => 'ci',
    sshkeys  => "\n",
  }
}
