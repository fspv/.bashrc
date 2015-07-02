# Set bashrc only for interactive sessions
# https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980
case "$-" in
*i*)
    if test -r ~/.bashrc
    then
        source ~/.bashrc
    fi
;;
esac
