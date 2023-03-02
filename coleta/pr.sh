#!/bin/sh
#
# File: pr.sh
# Date: 15/November/2021
# Build: 2.26 (15/November/2021)

# Copyright(c) Proteus Security Systems
#


# Instructions:
#
# 1) Connect to remote host via SSH or telnet.
#
# 2) Copy this script file to the host using ftp or scp.
#    Ex.:
#    	scp pr.sh user:
#
# 3) Run this script with root permissions
#    Ex.:
#       # id
#       uid=0(root) gid=0(root) grupos=0(root)
#       # ./pr.sh 
#
# 4) Send .tar* created to local machine
# 
# 5) Delete .tar* to host and logout
# 
# Echo Version
echo "Version: 2.26 (15/November/2021)
"

OSVER=`uname -s`

cleanup() {
  echo
  echo "[-] Exiting on term/quit signal..."
  
  echo "[-] Removing leftover files..."
  
  rm -rf $DIR
  
  exit 1
}
trap cleanup 2 3 9 15


# Echo Version
echo "Version: 2.26 (15/November/2021)
"
COPY_HASHES=0
BACKUP="no"
IGNORE_APACHE=0
IGNORE_TOMCAT=0

for parameter in $*; do
    key=`echo $parameter | awk -F= '{ print $1 }'`
    value=`echo $parameter | awk -F= '{ print $2 }'`

    case $key in
        --ignore-tomcat)
            IGNORE_TOMCAT=1
            echo "[++] Tomcat ignored"
            ;;
        --ignore-apache)
            IGNORE_APACHE=1
            echo "[++] Apache ignored"
            ;;
        --min-free-memory)
            MIN_FREE_MEMORY="$value"
            ;;

        --min-free-space)
            MIN_FREE_SPACE="$value"
            ;;

        --max-cpu-load)
            MAX_CPU_LOAD="$value"
            ;;

        --executewebsphere)
            EXEC_WEBSPHERE_TEMP=`echo $value | tr [A-Z] [a-z]`
            EXEC_WEBSPHERE="$EXEC_WEBSPHERE_TEMP"

                if [ -n "$EXEC_WEBSPHERE" ]; then

                        EXEC_WEBSPHERE_VALIDATION=`echo $EXEC_WEBSPHERE | egrep "^[ \t]*(yes|no)[ \t]*$"`

                        if [ ! -n "$EXEC_WEBSPHERE_VALIDATION" ]; then
                                printf "The value used in --execwebsphere option is not allowed.  Assuming the default \"no\".\n\n"
                                EXEC_WEBSPHERE="no"
                        fi
                else
                        EXEC_WEBSPHERE="no"
                fi
            ;;

        -workdir)
            DIR="$value"

		if [ -n "$DIR" ]; then
			DIRS_NOT_ALLOWED=`echo $DIR | egrep "(^[/]+$|^\/(var|var[/]+(log|adm)|etc|usr|(s)?bin|usr[/]+(s)?bin|opt|tmp)([/])*$)"`

			if [ -n "$DIRS_NOT_ALLOWED" ]; then
				printf "The value used in --workdir option is not allowed. Please choose another one.\n\n"
				exit 1
			fi
		else
			DIR="/tmp/.proteus/"
		fi
            ;;

        --remove-workdir-after)
	    REMOVE_DIR_TEMP=`echo $value | tr [A-Z] [a-z]`
	    REMOVE_DIR="$REMOVE_DIR_TEMP"
            
		if [ -n "$REMOVE_DIR" ]; then

			REMOVE_DIR_VALIDATION=`echo $REMOVE_DIR | egrep "^[ \t]*(yes|no)[ \t]*$"`

			if [ ! -n "$REMOVE_DIR_VALIDATION" ]; then
				printf "The value used in --remove-workdir-after option is not allowed.\ Assuming the default \"yes\".\n\n"
				REMOVE_DIR="yes"
			fi
		else
			REMOVE_DIR="yes"
		fi
            ;;


        --audit)
	    AUDIT_TEMP=`echo $value | tr [A-Z] [a-z]`
	    AUDIT="$AUDIT_TEMP"
            
		if [ -n "$AUDIT" ]; then

			AUDIT_VALIDATION=`echo $AUDIT | egrep "^[ \t]*(yes|no)[ \t]*$"`

			if [ ! -n "$AUDIT_VALIDATION" ]; then
				printf "The value used in --audit option is not allowed. Please choose \"yes\" or \"no\".\n\n"
				exit 1
			fi
		else
			AUDIT="no"
		fi
            ;;


        --backup)
	    BACKUP_TEMP=`echo $value | tr [A-Z] [a-z]`
	    BACKUP="$BACKUP_TEMP"
            
		if [ -n "$BACKUP" ]; then

			BACKUP_VALIDATION=`echo $BACKUP | egrep "^[ \t]*([0-9]+)[ \t]*$"`

			if [ ! -n "$BACKUP_VALIDATION" ]; then
				printf "The value used in --backup option is not allowed. Please choose any numeric value such as 1, 5, 10 etc.\n\n"
				exit 1
			else
				if [ "$BACKUP_VALIDATION" -eq "0" ]; then

					BACKUP="no"
				fi
			fi
		else
			BACKUP="no"
		fi
            ;;


        --prid)
                PRID_TEMP=`echo $value`
                PRID_VALIDATION=`echo $PRID_TEMP | egrep -i "^[ \t]*([a-z0-9]+|no)[ \t]*$"`

                if [ -z "$PRID_VALIDATION" ]; then

                        printf "The value used in --prid option is not allowed. Please choose \"<GUID>\" or \"no\".\n\n"
                        exit 1
                else

                        PRID_VALIDATION=`echo $PRID_TEMP | egrep -i "^[ \t]*(no)[ \t]*$"`
                        if [ -n "$PRID_VALIDATION" ]; then

                                activate_prid="0"
                        else

                                activate_prid="1"
                                PRID="$PRID_TEMP"
                        fi
                fi

                [ "$activate_prid" = "1" ] && {

                        CORRECTION_DIR="/var/security/backup/"
                        [ ! -d "$CORRECTION_DIR" ] && {

                                mkdir -p "$CORRECTION_DIR" 2>/dev/null
                                generate_prid="1"
                                echo "[+] Directory not found! Creating it"
                        }

                        if [ ! -f "$CORRECTION_DIR/.prid" ]; then

                                touch "$CORRECTION_DIR/.prid"
                                generate_prid="1"
                                echo "[+] PRID file not found! Creating it"
                        else

				echo "[+] PRID already exists! Checking the content"
                                validate_prid_content=`cat "$CORRECTION_DIR/.prid" 2>/dev/null | egrep "PRID\:.+"`
                                [ -z "$validate_prid_content" ] && {

                                        generate_prid="1"
                                }
                        fi

                        if [ "$generate_prid" = "1" ]; then

                                #PRID=`perl -le 'print map { sprintf q|%X|, rand(16) } 1..32' 2>/dev/null`
                                #[ -z "$PRID" ] && PRID=`python -c 'import uuid; x=str(uuid.uuid4().get_hex()).upper(); print (x)' 2>/dev/null`
                                #[ -z "$PRID" ] && PRID=`uuidgen | sed 's/\-//g' 2>/dev/null`
                                #[ -z "$PRID" ] && PRID=`openssl rand -hex 16 2>/dev/null | tr '[a-z]' '[A-Z]'`

                                echo "[+] Storing the PRID into the file"
                                echo "PRID: $PRID" > "$CORRECTION_DIR/.prid" 2>/dev/null
                        fi

                        echo "[+] Fixing permissions of PRID file and directory"
                        chmod 750 "$CORRECTION_DIR" 2>/dev/null
                        chmod 600 "$CORRECTION_DIR/.prid" 2>/dev/null

                        cat "$CORRECTION_DIR/.prid"
                        exit 0
                }
        ;;


        --help)
            printf "Usage:\n\n"
            printf " --min-free-memory=amount_in_kbytes\tMinimum free memory, in kbytes\n"
            printf " \t\t\t\t\tDefault value: empty (no restriction) \n\n"
            printf " --min-free-space=amount_in_kbytes\tMinimum free disk space, in kbytes\n"
            printf " \t\t\t\t\tDefault value: empty (no restriction) \n\n"
            printf " --max-cpu-load=max_cpu_load\t\tLimit percentage of CPU load\n"
            printf " \t\t\t\t\tDefault value: empty (no restriction) \n\n"
            printf " --workdir=/choose/a/directory\t\tDirectory used to copy files until the process is finished\n"
            printf " \t\t\t\t\tDefault value: /tmp/.proteus/ \n\n"
            printf " --remove-workdir-after=(yes/no)\tThis option will let the script to remove or not the temporary directory after the process is finished\n"
            printf " \t\t\t\t\tDefault value: yes \n\n"
            printf " --audit=(yes/no)\t\t\tThis option will let the script to copy or not some specific information for auditing\n"
            printf " \t\t\t\t\tDefault value: no \n\n"
	    printf " --prid=(<GUID>/no)\t\t\tThis option will let the script to generate an id in order to control if the asset is new or not\n"
	    printf " \t\t\t\t\tDefault value: no (no file will be saved in the /var/security/backup directory)\n\n"
	    printf " --backup=number_of_gathering_files\t\tThis option will let the script to save a number of gathering files in the server\n"
	    printf " \t\t\t\t\tDefault value: no (no file will be saved in the /var/security/ directory)\n\n"
	    printf "Example: sh $0 --min-free-memory=8192 --min-free-space=102400 --max_cpu_load=50 --workdir=/tmp/086c462e52f8 --remove-workdir-after=no --audit=yes --backup=5\n\n"
            printf "NOTE: When specified values are reached, the gathering will be aborted (only for resources/limit).\n\n"
            exit 1
            ;;
    esac
done

   echo "[++] Setting up the Gathering Common Unix library "

#UNIX COMMON LIBRARY

OS=""
PS_COMMAND=""

if [ -f "/usr/ucb/ps" ]; then

        PS_SUNOS="/usr/ucb/ps -auxwww"
else

        PS_SUNOS="/usr/bin/ps auxwww"
fi

PS_LINUX="ps auxewww"

#===  FUNCTION  ================================================================
#          NAME:  kill_rpm
#   DESCRIPTION:  Monitors rpm command to avoid big delays and kill it in case
#		  the process achives the maximum time
#    PARAMETERS:  $1 = tmout (in seconds)
#===============================================================================

kill_rpm() {

        rpm_tmout="$1"
        rpm_tmout_status="0"
        rpm_control="1"

        [ -z "$rpm_tmout" ] || [ "$rpm_tmout" -le "0" ] && {

                #default tmout is 6minutes
                rpm_tmout="360"
        }

        while [ "$rpm_control" = "1" ]; do

                test_rpm_ps=`ps aux | grep -v grep | egrep "rpm \-qa"`
                test_rpm_ps_id=`ps aux | grep -v grep | egrep "rpm \-qa" | awk '{ print $2 }'`
                rpm_tmout_status=`expr $rpm_tmout_status + 1`
                sleep 1

                if [ -n "$test_rpm_ps" ]; then

                        while [[ "$rpm_tmout" -lt "$rpm_tmout_status" ]]; do

                                if [ -z "$test_rpm_ps" ]; then

                                        rpm_control="0"
                                        break
                                else

                                        kill -9 ${test_rpm_ps_id} 2>/dev/null && echo "[+++] Killing rpm zombie process..."
                                        rpm_control="0"
                                        break
                                fi

                                rpm_tmout_status=`expr $rpm_tmout_status + 1`
                        done
                else

                        rpm_control="0"
                fi
        done
}
#===============================================================================

#===  FUNCTION  ================================================================
#          NAME:  detect_unix_flavor
#   DESCRIPTION:  Detect the unix distro
#    PARAMETERS:  --
#       RETURNS:  0 = detected ; 1 = impossible to detect
#===============================================================================

detect_unix_flavor () {

  uname_path=`which uname`

  if [ -z "$uname_path" ]; then

    return 1 #FIXME- 

  fi

  OS=`$uname_path`
  
  return 0

}

#===  FUNCTION  ================================================================
#          NAME:  detect_ps
#   DESCRIPTION:  Retrieve the process list according OS flavor 
#    PARAMETERS:  --
#       RETURNS:  0 = success ; 1 = failure
#===============================================================================

detect_ps () {

  #Looking for Unix flavor
  if [ -z "$OS" ]; then

    detect_unix_flavor

    if [ $? -ne 0 ]; then

      return 1 #FIXME

    fi
  
  fi

  case "$OS" in
    'Linux')
      PS_COMMAND=$PS_LINUX
    ;;

    'SunOS')
      PS_COMMAND=$PS_SUNOS
    ;;

    *)
      #echo "Impossible to retrieve Unix flavor or Unix not supported."
      return 1 #FIXME
    ;;

  esac


  return 0

}

#===  FUNCTION  ================================================================
#          NAME:  remove_dup
#   DESCRIPTION:  Receives a list of strings and strip the repetition. 
#    PARAMETERS:  $1 = (string) list of strings, \n separated.
#                 $2 = (integer) Maximum size of string comparison.(optional)
#       RETURNS:  0 = success ; 1 = failure
#===============================================================================

remove_dup () {

  [ $# -lt 1 ] && return 1

  max="$2"

  if [ -n "$max" ]; then

    echo "$1" | awk -v max="$max" '!x[substr($0,1,max)]++'

  else

    echo "$1" | awk '!x[$0]++'

  fi

  return 0

}

#===  FUNCTION  ================================================================
#          NAME:  get_home_directories 
#   DESCRIPTION:  Retrieves all home directories from /etc/passwd. 
#    PARAMETERS:  $1 = sort absolute path (optional) 
#       RETURNS:  0 = success ; 1 = failure
#===============================================================================

get_home_directories() {

  sort_path="$1"

  if [ -n "$sort_path" ]; then

    home_dir_list=`grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u`

  else

    home_dir_list=`grep -v "^#" /etc/passwd | cut -d: -f6`
    home_dir_list=`remove_dup "$home_dir_list"`

  fi

  echo "$home_dir_list" | tr "\n" " "

  return 0

}









#===  FUNCTION  ================================================================
#          NAME:  get_free_memory 
#   DESCRIPTION:  Obtain the amount of free memory in the system
#    PARAMETERS:  -- 
#       RETURNS:  Free memory
#===============================================================================
get_free_memory () {
    osname=`uname -s`

    case $osname in
        Linux)
            echo `get_free_memory_linux`
            ;;
        FreeBSD)
            echo `get_free_memory_freebsd`
            ;;
        OpenBSD)
            echo `get_free_memory_openbsd`
            ;;
        HP-UX)
            echo `get_free_memory_hpux`
            ;;
        AIX)
            echo `get_free_memory_aix`
            ;;
        SunOS)
            echo `get_free_memory_sunos`
            ;;
    esac

}



#===  FUNCTION  ================================================================
#          NAME:  get_cpu_load 
#   DESCRIPTION:  Obtain the CPU load
#    PARAMETERS:  -- 
#       RETURNS:  Load avg
#===============================================================================
get_cpu_load () {
    osname=`uname -s`

    case $osname in
        Linux)
            echo `get_cpu_load_linux`
            ;;
        FreeBSD)
            echo `get_cpu_load_freebsd`
            ;;
        OpenBSD)
            echo `get_cpu_load_openbsd`
            ;;
        HP-UX)
            echo `get_cpu_load_hpux`
            ;;
        AIX)
            echo `get_cpu_load_aix`
            ;;
        SunOS)
            echo `get_cpu_load_sunos`
            ;;
    esac

}




#===  FUNCTION  ================================================================
#          NAME:  get_free_tmp_space 
#   DESCRIPTION:  Obtain the amount of free space where /tmp belongs
#    PARAMETERS:  -- 
#       RETURNS:  Free disk space in /tmp, measured in bytes 
#===============================================================================
get_free_tmp_space () {
    osname=`uname -s`

    case $osname in
        Linux)
            echo `get_free_tmp_space_linux`
            ;;
        FreeBSD)
            echo `get_free_tmp_space_freebsd`
            ;;
        OpenBSD)
            echo `get_free_tmp_space_openbsd`
            ;;
        HP-UX)
            echo `get_free_tmp_space_hpux`
            ;;
        AIX)
            echo `get_free_tmp_space_aix`
            ;;
        SunOS)
            echo `get_free_tmp_space_sunos`
            ;;
    esac

}



#===  FUNCTION  ================================================================
#          NAME:  save_ps_output 
#   DESCRIPTION:  Save the output of ps into a file 
#    PARAMETERS:  $1 = output file
#       RETURNS:  Write file with ps output
#===============================================================================
save_ps_output () {
    osname=`uname -s`

    case $osname in
        Linux)
            ps aux > "$1" 
            ;;
        FreeBSD)
            ps > "$1"            
            ;;
        OpenBSD)
            ps > "$1" 
            ;;
        HP-UX)
            ps > "$1" 
            ;;
        AIX)
            ps aux > "$1" 
            ;;
        SunOS)
            [ -f "/usr/ucb/ps" ] && /usr/ucb/ps aux > "$1"
            [ ! -s "$1" ] && [ -f "/usr/bin/ps" ] && /usr/bin/ps aux > "$1"
            ;;
    esac

}




#===  FUNCTION  ================================================================
#          NAME:  verify_resources 
#   DESCRIPTION:  Verify if the machine is overloaded and abort the
#                 gathering if necess<D-1>ary.
#    PARAMETERS:  -- 
#       RETURNS:  --
#===============================================================================
verify_resources () {
    [ ! -d "./monitor" ] && mkdir ./monitor


    # Save ps output into a file
    data=`date "+%m%d_%H%M%S"`
    save_ps_output "./monitor/ps_$data.txt" 

    # Obtain free memory and disk space in /tmp
    free_mem=`get_free_memory`
    free_tmp=`get_free_tmp_space`
    cpu_load=`get_cpu_load`
   
    # Print information into log
    printf "`date` Free memory: $free_mem \t Free disk space: $free_tmp \t CPU Load: $cpu_load \n" >> ./monitor/resources.log


    #
    # If there's not enough free mem, cpu or space, abort the gathering
    #
   
    if [ -n "$MIN_FREE_MEMORY" ] &&  [ "$free_mem" -lt "$MIN_FREE_MEMORY" ]; then
            echo ""
            echo "[+] ERROR: memory limit reached. Aborting gathering."
            echo ""
            echo "    Available memory: $free_mem"
            echo "     MIN_FREE_MEMORY: $MIN_FREE_MEMORY"
            echo ""
            exit 1
    fi

    if [ -n "$MIN_FREE_SPACE" ] && [ "$free_tmp" -lt "$MIN_FREE_SPACE" ]; then
            echo ""
            echo "[+] ERROR: free disk space limit reached. Aborting gathering."
            echo ""
            echo "    Available disk space: $free_tmp"
            echo "          MIN_FREE_SPACE: $MIN_FREE_SPACE"
            echo ""
            exit 1
    fi

    
    if [ -n "$MAX_CPU_LOAD" ] && [ "`echo $cpu_load $MAX_CPU_LOAD | awk '{ if ($1 > $2) { print \"1\" } else { print \"0\" } }'`" = "1" ]; then
            echo ""
            echo "[+] ERROR: maximum CPU load limit reached. Aborting gathering."
            echo ""
            echo "        CPU load: $cpu_load"
            echo "    MAX_CPU_LOAD: $MAX_CPU_LOAD"
            echo ""

            exit 1
    fi





    
}








#===  FUNCTION  ================================================================
#          NAME:  chkconfig_list 
#   DESCRIPTION:  Gather the services configurations by runlevel. 
#    PARAMETERS:  -- 
#       RETURNS:  0 = success
#===============================================================================

chkconfig_list () {

  mkdir chkconfig
  _tpl="chkconfig/services_rc" # Template file name for temporary services list files.

  for dir in `ls /etc | sed -n '/^rc[0-9]/p'`
  do

    runlevel=`echo $dir | sed -n 's/^rc\([0-9]\).*/\1/p'`
    dir="/etc/$dir"
    tmp_file="${_tpl}${runlevel}"

    for file in `ls $dir | sed -n -e '/^S[0-9]\{2\}/p' -e '/^K[0-9]\{2\}/p'`
    do

      status=`echo $file | sed -n 's/^\([A-Z]\).*/\1/p'`
      [ "X$status" = "XS" ] && status="on"
      [ "X$status" = "XK" ] && status="off"
      id=`echo $file | sed -n 's/^[A-Z]\([0-9]\{2\}\).*/\1/p'`
      service=`echo $file | sed -n 's/^[A-Z][0-9]\{2\}\(.*\)/\1/p'`

      printf "$service ${runlevel}:$status\n" >> ${_tpl}${runlevel}

    done

  done

  unset _tpl dir runlevel tmp_file file status id service

  return 0

}

#===  FUNCTION  ================================================================
#          NAME:  gather_kernel_param 
#   DESCRIPTION:  Gather the kernel parameters from a list. 
#    PARAMETERS:  -- 
#       RETURNS:  0 = success ; 1 = gather file exists
#===============================================================================

gather_kernel_params () {

  [ -f "kernel_parameters" ] && return 1

  base_dir="/proc/sys"
  kernel_params="net.ipv4.tcp_syncookies net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.log_martians net.ipv4.icmp_echo_ignore_broadcasts net.ipv4.conf.all.rp_filter net.ipv4.conf.all.forwarding net.ipv4.conf.all.accept_source_route kernel.exec-shield fs.suid_dumpable kernel.randomize_va_space net.ipv4.icmp_ignore_bogus_error_responses net.ipv4.conf.all.send_redirects net.ipv6.conf.all.accept_ra" 

  for param in $kernel_params; do

    file=`echo "$param" | tr "." "\/"`
    file="$base_dir/$file"


    [ -f "$file" ] && {

      value=`cat $file`
      echo "${param}=${value}" >> kernel_parameters 

    }

  done

  unset base_dir kernel_params param file value

}

#===  FUNCTION  ================================================================
#          NAME:  get_shadow
#   DESCRIPTION:  Copy the shadow failes to gathering directory. 
#    PARAMETERS:  -- 
#       RETURNS:  --
#===============================================================================
get_shadow() {

  [ $# -eq 0 ] && return 1

  AWK=`which awk`

  #Solaris
  [ -f "/usr/xpg4/bin/awk" ] && AWK="/usr/xpg4/bin/awk"

  shadow_files="/etc/shadow
/etc/gshadow /etc/master.shadow /etc/master.passwd /etc/passwd"

  for shadow_file in $shadow_files; do
    if [ -f "$shadow_file" ]; then
      output_file=`basename $shadow_file`
      $AWK -v COPY_HASHES=$1 -v OUTPUT_FILE=$output_file 'function extract_lock_info(hash)
        {
          if (match($2,"^[*!]+"))
            return "NOPASS"
          else
            return "PASS"
        }
        
        BEGIN {
          OFS=FS=":"
          if (COPY_HASHES == "")
            COPY_HASHES = 0
        }
        
        {
          hash_info = extract_lock_info($2)
        
          if (!COPY_HASHES)
            $2 = ""

          output_file = "./user_hash_info_" OUTPUT_FILE
          print $1 ":" hash_info >> output_file 
        
          print
          
        }' $shadow_file >> ./$output_file
    else
      ls -la "$shadow_file" >> ./not-found.txt 2>&1
    fi
  done
	
	###################################################
	# Avoiding to collect any sensitive information
	# password or hashes
	###################################################
	if [ "$OSVER" = "OSF1" ]; then

		if [ -f "./passwd" ]; then
	 		cat passwd | awk -F ":" '{ print $1 "::" $3 ":" $4 ":" $5 ":" $6 ":" $7 }' > passwd.temp 2>/dev/null
			mv passwd.temp passwd 2>/dev/null
		fi
		
	fi
	###################################################
}
#===============================================================================

#===  FUNCTION  ================================================================
#          NAME:  collect_gcc_perms
#   DESCRIPTION:  Collect gcc and cc permissions
#    PARAMETERS:  -- 
#       RETURNS:  --
#===============================================================================
collect_gcc_perms () {

        echo "" > ./cc.txt
        path="/bin /sbin /usr/bin /usr/contrib/bin /usr/contrib/sbin /usr/local/bin /usr/local/sbin /usr/sbin /usr/xpg4/bin /usr/xpg4/sbin"

        files_gcc=`find $path ! -type d -prune -name gcc \( -perm -g=x -o -perm -g=w -o -perm -o=x -o -perm -o=w \) 2>>./not-found.txt`
        files_cc=`find $path ! -type d -prune -name cc \( -perm -g=x -o -perm -g=w -o -perm -o=x -o -perm -o=w \) 2>>./not-found.txt`
        files=`echo "$files_gcc" "$files_cc" | tr " " "\n" | sort | uniq`
	awk=`which awk`

	if [ -z "$awk" -a ! -f "/usr/bin/nawk" ]; then

		return 
	else

		system=`uname -s`
		[ "$system" = "SunOS" ] && { 

			if [ -f "/usr/bin/nawk" ]; then

				awk="/usr/bin/nawk"

			else

				return
			fi
		}
	fi

        for file in ${files}; do

                [ ! -f "$file" ] && [ ! -h "$file" ] && continue

                orig_file_location=`dirname $file`
                is_sym=`ls -l $file | $awk ' $0 ~ /^l........./ { print $NF } '`
                found_file=""
        	real_file=""

                if [ -n "$is_sym" ]; then

                        add_path_prefix=`echo $is_sym | egrep "^[ \t\s]*\/"`
                        dest_file="$is_sym"
                        path_dest_file=`dirname "$original_file_location"`

                        [ -z "$path_dest_file" ] || [ "$path_dest_file" = "." ] && path_dest_file="$orig_file_location"

                        while [ -z "$found_file" ]; do

                                if [ -z "$add_path_prefix" ]; then

                                        is_sym_2=`ls -l $path_dest_file/$dest_file | $awk ' $0 ~ /^l........./ { print $NF } '`
                                else

                                        is_sym_2=`ls -l $dest_file | $awk ' $0 ~ /^l........./ { print $NF } '`
                                fi

                                if [ -n "$is_sym_2" ]; then

                                        add_path_prefix=`echo $is_sym_2 | egrep "^[ \t\s]*\/"`
                                        dest_file="$is_sym_2"
                                        path_dest_file="$path_dest_file"

                                        if [ -z "$add_path_prefix" ]; then

                                                is_sym_2=`ls -l $path_dest_file/$dest_file | $awk ' $0 ~ /^l........./ { print $NF } '`
                                        else

                                                is_sym_2=`ls -l $dest_file | $awk ' $0 ~ /^l........./ { print $NF } '`
                                        fi

                                        [ -z "$is_sym_2" ] && {

                                                ls -l $path_dest_file/$dest_file | \
                                                        $awk -v real_file="$file" ' $NF=real_file { print $0 } ' >> ./cc.txt 2>>./not-found.txt
                                                found_file="ok"
                                        }
                                else

                                        if [ -z "$add_path_prefix" ]; then

                                                ls -l $path_dest_file/$dest_file | \
                                                        $awk -v real_file="$file" ' $NF=real_file { print $0 } ' >> ./cc.txt 2>>./not-found.txt
                                        else

                                                ls -l $dest_file | $awk -v real_file="$file" ' $NF=real_file { print $0 } ' >> ./cc.txt 2>>./not-found.txt
                                        fi
                                        found_file="ok"
                                fi
                        done
                else

                        real_file="$file"
                        ls -l "$real_file" >> ./cc.txt 2>>./not-found.txt
                fi
        done

        return 0
}
#===============================================================================



########################################################
# Enhanced echo/echo -n
########################################################
if [ "X`echo -n`" = "X-n" ]; then
        echo_n() {
                echo ${1+"$@"}"\c"
                return
        }
else
        echo_n() {
                echo -n ${1+"$@"}
                return
        }
fi
########################################################
#
if [ "$OSVER" != "VMkernel" ]; then
  my_id=`id | sed 's/^.*uid=\([0-9]*\).*$/\1/'`
  if [ "$my_id" != "0" ]; then
    echo "[+] This script requires root privileges to run!"
    exit 255
  fi
fi
LANG=C
export LANG
PATH=/usr/xpg4/bin:$PATH:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin:/opt/sudo/bin:/opt/sudo/bin/sudo:/usr/lbin:/usr/contrib/bin
export PATH
maq=`uname -n`

if [ ! -n "$DIR" ]; then
        DIR=/tmp/.proteus
fi

if [ ! -n "$AUDIT" -o "$AUDIT" = "no" ]; then
        COPY_HASHES=0
else
        COPY_HASHES=1
fi

cur_dir=`pwd`
echo "[++] Machine Name: $maq"
rm -rf $DIR/$maq
mkdir -p $DIR/$maq
chmod 700 $DIR
cd $DIR/$maq
DIRCOL=`pwd`
GATHER_TYPE="local"
[ ! -d $DIRCOL/logs ] && mkdir $DIRCOL/logs
DEBUG_LOG=$DIRCOL/logs/debug.log
unalias cp 2> /dev/null
unalias rm 2> /dev/null


echo "2.26 (15/November/2021)
" > $DIR/$maq/version.txt

case $OSVER in
VMkernel)
   echo "[+] Collecting VMkernel" >> $DEBUG_LOG
   echo "[+] Collecting VMkernel"

# beginning of functions
cleanup() {

	echo
	echo "[-] Exiting on term/quit signal..."
  
	echo "[-] Removing leftover files..."
  
	rm -rf $DIR
  
	exit 1
}
trap cleanup 2 3 9 15

get_version_and_infos() {

	[ -f "/bin/vmware" -o "/usr/bin/vmware" ] && [ -d "/etc/vmware" ] && touch ./.vmware_esx

        uname -a > ./uname.txt
        hostname > ./hostname.txt

        vmware -v > ./sw_version.txt

	if [ "$mver" = "5x" ]; then

		vmware -l > ./sw_level.txt
		ps -c > ps-c.txt
	else

		touch ./sw_level.txt
		ps aux > ps-c.txt
	fi

}

get_firewall_status() {

	if [ "$mver" = "5x" ]; then

        	esxcli --formatter=keyvalue network firewall get 2>/dev/null | awk -F= ' $0 ~ /Enabled/ { print $2 }' > ./fw_status.txt
	else

		chains=`service firewall status 2>/dev/null | egrep -i "policy[[:blank:]]+ACCEPT" | wc -l | egrep -o "[0-9]+"`
		if [ -z "$chains" -o "$chains" = "0" ]; then
		
			echo "true" > ./fw_status.txt
		else

			echo "false" > ./fw_status.txt
		fi
	fi

}

get_ntpd_status() {

        ntpd_init_script="/etc/init.d/ntpd"
        if [ -f "$ntpd_init_script" ]; then

                sh $ntpd_init_script status > ./ntpd.txt
        else

                echo "error:status_not_available" > ./ntpd.txt
        fi
}

get_vswitches() {


	if [ "$mver" = "5x" ]; then

        	esxcli network vswitch standard list 2>/dev/null | egrep "^[^ ]" > ./vswitches.txt

	else

		esxcfg-vswitch -l  2>/dev/null | sed "1d" | egrep "^[^ ]" | awk '{ print $1 }' > ./vswitches.txt
		vmware-vim-cmd hostsvc/net/config 2>/dev/null | egrep "(name|allowPromiscuous|macChanges|forgedTransmits)" > ./.net_properties.txt
		vmware-vim-cmd hostsvc/net/vswitch_info 2>/dev/null | egrep "(name|allowPromiscuous|macChanges|forgedTransmits)" > ./.vswitches_properties.txt
	fi

        vs_names=`cat ./vswitches.txt`
        for vs in ${vs_names}; do

		if [ "$mver" = "5x" ]; then

                	esxcli --formatter=keyvalue network vswitch standard policy security get -v="$vs" 2>/dev/null | awk -v vs="$vs" '{ print vs";"$0 }' >> ./vswitches_properties.txt
			echo >> ./vswitches_properties.txt
		else

			vmware-vim-cmd hostsvc/net/vswitch_info "$vs" 2>/dev/null >> ./vswitches_properties.txt
			echo >> ./vswitches_properties.txt
		fi
        done
}

get_port_groups() {

	if [ "$mver" = "5x" ]; then

        	esxcli --formatter=keyvalue network vswitch standard portgroup list | egrep "\.Name\." | awk -F= '{ print $2 }' 2>/dev/null > ./portgroups.txt
	else

		esxcfg-vswitch -l 2>/dev/null > ./portgroups.txt
	fi
}

get_user_privileges() {

	if [ "$mver" = "5x" ]; then
        
		vim-cmd vimsvc/auth/permissions 2>/dev/null > ./user_privileges.txt
	else

		vmware-vim-cmd vimsvc/auth/permissions 2>/dev/null > ./user_privileges.txt
		cp /etc/passwd ./passwd.txt
	fi
}

get_syslog_confs() {

	if [ "$mver" = "5x" ]; then

        	esxcli --formatter=keyvalue  system syslog config get 2>/dev/null > ./syslog_confs.txt
	else

		cp /etc/syslog.conf ./syslog.conf 2>/dev/null
	fi
}

get_ifconfig(){

	if [ "$mver" = "5x" ]; then

        	esxcli network ip interface ipv4 get 2>/dev/null | sed '1,2d' | awk ' $2 ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ { print $1":"$2; exit; }' > ./ifconfig-a.txt
	else

		esxcfg-vswif -l 2>/dev/null | sed '1d' | awk ' $4 ~ /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ { print $1":"$4; exit; }' > ./ifconfig-a.txt
		ifconfig | egrep "inet addr" | sed -n 's/.*\(inet addr\:[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | awk -F':' ' $0 !~ /127\.0\.0/ { print "int0:"$2 }' >./.ifconfig-a.txt
	fi
}

get_active_vmx() {

	if [ "$mver" = "5x" ]; then

		esxcli --formatter=csv vm process list | awk -F',' ' $0 ~ /\.vmx/ { print $1 }' 2>/dev/null > ./active_vmx.txt
	else
	
		vmware-vim-cmd vmsvc/getallvms 2>/dev/null | awk ' $1 ~ /[0-9]+/ { print $1 }' > ./all_vmx.txt
		vm-support -x 2>/dev/null > ./active_vmx.txt
	fi
}

get_vmware_tools_params() {

        mkdir -p ./vmware_tools_params

	#default
        default_copy=`cat /etc/vmware/config 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.copy\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
        if [ -n "$default_copy" ]; then

                echo "copy:$default_copy" >> ./vmware_tools_params/default.txt
        else

		default_copy="true"
                echo "copy:$default_copy" >> ./vmware_tools_params/default.txt
        fi

        default_paste=`cat /etc/vmware/config 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.paste\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
        if [ -n "$default_paste" ]; then

                echo "paste:$default_paste" >> ./vmware_tools_params/default.txt
        else

		default_paste="true"
                echo "paste:$default_paste" >> ./vmware_tools_params/default.txt
        fi

        default_dnd=`cat /etc/vmware/config 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.dnd\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
        if [ -n "$default_dnd" ]; then

                echo "dnd:$default_dnd" >> ./vmware_tools_params/default.txt
        else

		default_dnd="true"
                echo "dnd:$default_dnd" >> ./vmware_tools_params/default.txt
        fi

        default_setGUIOptions=`cat /etc/vmware/config 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.setGUIOptions\.enable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
        if [ -n "$default_setGUIOptions" ]; then

                echo "setGUIOptions:$default_setGUIOptions" >> ./vmware_tools_params/default.txt
        else

		default_setGUIOptions="false"
                echo "setGUIOptions:$default_setGUIOptions" >> ./vmware_tools_params/default.txt
        fi

        default_device_connectable=`cat /etc/vmware/config 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.device\.connectable\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
        if [ -n "$default_device_connectable" ]; then

                echo "setGUIOptions:$default_device_connectable" >> ./vmware_tools_params/default.txt
        else

		default_device_connectable="true"
                echo "device_connectable:$default_device_connectable" >> ./vmware_tools_params/default.txt
        fi

        default_device_edit=`cat /etc/vmware/config 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.device\.edit\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
        if [ -n "$default_device_edit" ]; then

                echo "device_edit:$default_device_edit" >> ./vmware_tools_params/default.txt
        else

		default_device_edit="true"
                echo "device_edit:$default_device_edit" >> ./vmware_tools_params/default.txt
        fi

	#per vmx
        list_of_vmx=`cat ./active_vmx.txt`
        for list in ${list_of_vmx}; do
			if [ -n $list -a -f "$list" ] ; then
				echo "Found file on vmx list: $list"
                                vmx_copy=`cat "$list" 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.copy\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
                                if [ -n "$vmx_copy" ]; then

                                        echo "$list:copy:$vmx_copy" >> ./vmware_tools_params/vmx.txt
                                else

                                        echo "$list:copy:$default_copy" >> ./vmware_tools_params/vmx.txt
                                fi

                                vmx_paste=`cat "$list" 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.paste\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
                                if [ -n "$vmx_paste" ]; then

                                        echo "$list:paste:$vmx_paste" >> ./vmware_tools_params/vmx.txt
                                else

                                        echo "$list:paste:$default_paste" >> ./vmware_tools_params/vmx.txt
                                fi

				vmx_dnd=`cat "$list" 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.dnd\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
				if [ -n "$vmx_dnd" ]; then

						echo "$list:dnd:$vmx_dnd" >> ./vmware_tools_params/vmx.txt
				else

						echo "$list:dnd:$default_dnd" >> ./vmware_tools_params/vmx.txt
				fi

				vmx_setGUIOptions=`cat "$list" 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.tools\.setGUIOptions\.enable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
				if [ -n "$vmx_setGUIOptions" ]; then

						echo "$list:setGUIOptions:$vmx_setGUIOptions" >> ./vmware_tools_params/vmx.txt
				else

						echo "$list:setGUIOptions:$default_setGUIOptions" >> ./vmware_tools_params/vmx.txt
				fi

				vmx_device_connectable=`cat "$list" 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.device\.connectable\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
				if [ -n "$vmx_device_connectable" ]; then

						echo "$list:device_connectable:$vmx_device_connectable" >> ./vmware_tools_params/vmx.txt
				else

						echo "$list:device_connectable:$default_device_connectable" >> ./vmware_tools_params/vmx.txt
				fi

				vmx_device_edit=`cat "$list" 2>/dev/null | egrep -i "^[[:blank:]]*isolation\.device\.edit\.disable[[:blank:]]*=" | awk -F= '{ print $2 }' | tail -n1`
				if [ -n "$vmx_device_edit" ]; then

						echo "$list:device_edit:$vmx_device_edit" >> ./vmware_tools_params/vmx.txt
				else

						echo "$list:device_edit:$default_device_edit" >> ./vmware_tools_params/vmx.txt
				fi
		        fi
		echo >> ./vmware_tools_params/vmx.txt
        done
}


get_vmware_tools_params_old() {

	mkdir -p ./vmware_tools_params
	all_vms=`cat ./all_vmx.txt`

	for each_vm in ${all_vms}; do

		vmware-vim-cmd vmsvc/get.config "$each_vm" > ./vmware_tools_params/$each_vm.txt 2>/dev/null
	done
}

help() {

args=`echo "$args" | sed 's/ /\n/g'`
for parameter in ${args}; do

    key=`echo $parameter | awk -F= '{ print $1 }'`
    value=`echo $parameter | awk -F= '{ print $2 }'`

    case $key in

        --workdir)
            DIR="$value"

                if [ -n "$DIR" ]; then
                        DIRS_NOT_ALLOWED=`echo $DIR | egrep "(^[/]+$|^\/(var|var[/]+(log|adm)|etc|usr|(s)?bin|usr[/]+(s)?bin|opt|tmp)([/])*$)"`

                        if [ -n "$DIRS_NOT_ALLOWED" ]; then
                                printf "The value used in --workdir option is not allowed. Please choose another one.\n\n"
                                exit 1
                        fi
                else
                        DIR="/tmp/.proteus/"
                fi
            ;;

        --remove-workdir-after)
        
            REMOVE_DIR_TEMP=`echo $value | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`
            REMOVE_DIR="$REMOVE_DIR_TEMP"

                if [ -n "$REMOVE_DIR" ]; then

                        REMOVE_DIR_VALIDATION=`echo $REMOVE_DIR | egrep "^[ \t]*(yes|no)[ \t]*$"`

                        if [ ! -n "$REMOVE_DIR_VALIDATION" ]; then
                                printf "The value used in --remove-workdir-after option is not allowed. Please choose \"yes\" or \"no\".\n\n"
                                exit 1
                        fi
                else
                        REMOVE_DIR="yes"
                fi
            ;;

        --help)
        
            printf "Usage:\n\n"
            printf " --workdir=/choose/a/directory\t\tDirectory used to copy files until the process is finished\n"
            printf " \t\t\t\t\tDefault value: /tmp/.proteus/ \n\n"
            printf " --remove-workdir-after=(yes/no)\tThis option will let the script to remove or not the temporary directory after the process is finished\n"
            printf " \t\t\t\t\tDefault value: yes \n\n"
            exit 1
            ;;

	esac
done

}

        echo "[+] Collecting ESXi" >> $DEBUG_LOG
        echo "[+] Collecting ESXi"         

mver="5x" 

get_version_and_infos
get_ifconfig
get_ntpd_status
get_firewall_status
get_user_privileges
get_vswitches
get_port_groups
get_syslog_confs
get_active_vmx
get_vmware_tools_params
  ;;
FreeBSD)
   echo "[+] Collecting FreeBSD" >> $DEBUG_LOG
   echo "[+] Collecting FreeBSD"
NETSTAT=`which netstat`

CP_FILES="/boot/loader.conf
/etc/auth.conf
/etc/aliases
/etc/crontab
/etc/exports
/etc/fstab
/etc/ftpusers
/etc/group
/etc/grub.conf
/etc/inetd.conf
/etc/lilo.conf
/etc/login.conf
/etc/mac.conf
/etc/motd 
/etc/issue
/etc/passwd
/etc/pf.conf 
/etc/profile
/etc/rc.conf
/etc/resolv.conf
/etc/shells
/etc/sysctl.conf
/etc/syslog.conf
/etc/ttys
/var/at/at.allow
/etc/ftp*
/etc/hosts*
/etc/*shrc
/etc/rc*
/etc/nsswitch.conf
"

PROCESSES="ps awwxo command"


#
#
# FreeBSD monitoring commands
#
#

# Function to obtain free memory
get_free_memory_freebsd () {
    MemFree=`vmstat -H | awk '/^([ \t]*[0-9]+)*$/ { print $5 }'`
    echo $MemFree    
}
# Function to obtain load average 
get_cpu_load_freebsd () {
    CpuLoad=`ps aux | grep -v '\[idle: .*\]$' | awk 'BEGIN { cpu=0 }{ if (match($3,/[0-9].[0-9]/)) { cpu=cpu+$3 } } END { print cpu }'`
    echo $CpuLoad
}
# Function to obtain free disk space on /tmp
get_free_tmp_space_freebsd () {
    # Try to get free space in /tmp
    free_space_tmp=`df -k -l | awk '/\/tmp$/ { print $4 }'`

    # If it fails, try /
    if [ -z "$free_space_tmp" ]; then
        free_space_tmp=`df -k -l | awk '($NF == "/") { print $4 }'`
    fi

    echo "$free_space_tmp"
}

verify_resources


echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

get_shadow "$COPY_HASHES"

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt 2>&1
         fi


         echo -n "."
      else
         ls -la "$f" 1>> ./not-found.txt 2>&1
      fi
done
echo

mkdir ./usr
mkdir ./usr/local
mkdir ./usr/local/etc

mkdir ./boot
mkdir ./boot/defaults
cp /boot/defaults/loader.conf ./boot/defaults/loader.conf 2>> ./not-found.txt

mkdir ./etc
cp -r /etc/defaults/ ./etc/defaults/ 2>> ./not-found.txt

cp /var/cron/allow cron.allow

lastlogin > ./lastlog.txt  2>> ./not-found.txt

cp -R /etc/pam.d/su . 2>> ./not-found.txt

cp -R /etc/pam.d/ ./pam.d 2>> ./not-found.txt

cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/.kshrc kshrc-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root  2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login csh.login-root 2>> ./not-found.txt


verify_resources


echo "[++] Searching Permissions" >> $DEBUG_LOG
echo "[++] Searching Permissions"
collect_gcc_perms
[ -n "`which su`" ] && ls -lL `which su` 1> su_perm.txt 2>> ./not-found.txt
ls -ld `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u` >> home_listagem.txt 2>&1
ls -lad /tmp /var/tmp > tmps_listagem.txt 2>&1

find /etc \( -type f -o -type d \) \( -perm -g=w -o -perm -o=w \) -exec ls -ld {} \; > etc_find.txt 2>/dev/null
ls -l /etc 1> etc_ls.txt
ls -la /var/log > varlog_listagem.txt 2>> ./not-found.txt



verify_resources


echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

dmesg > dmesg.txt 2>&1
hostname > hostname.txt 2>&1
id > id.txt 2>&1
ifconfig -a > ifconfig-a.txt 2>&1

if [ -n "$NETSTAT" ]; then

  netstat -na > netstat-na.txt 2>&1
  netstat -nr > netstat-nr.txt 2>&1

else

  cp --parents /proc/net/unix /proc/net/tcp /proc/net/tcp6 /proc/net/route . 2>> ./not-found.txt

fi
sockstat -4l > sockstat-4l.txt 2>&1
ps auxww > ps-auxww.txt 2>&1
set > set.txt 2>&1
sysctl -a > sysctl-a.txt 2>&1
uname -a > uname.txt 2>&1
w > w.txt 2>&1
kldstat -v > kldstat.txt 2>&1
pkg_info > pkginfo.txt 2>&1
hostid > hostid.txt 2>> ./not-found.txt

verify_resources


echo "[++] Colectting SUIDs" >> $DEBUG_LOG
echo "[++] Colectting SUIDs"
for h in `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u`; do
     [ -s $h/.netrc ] && {
           ls -ld $h/.netrc >> netrc.txt
     }
     [ -s $h/.rhosts ] && {
          ls -ld $h/.rhosts >> rhosts.txt
          cat $h/.rhosts >> rhosts.txt
     }
done
  ;;
OpenBSD)
   echo "[+] Collecting OpenBSD" >> $DEBUG_LOG
   echo "[+] Collecting OpenBSD"

CP_FILES="/etc/aliases
/etc/exports
/etc/fstab
/etc/group
/etc/inetd.conf
/etc/login.conf
/etc/motd 
/etc/issue
/etc/passwd 
/etc/profile
/etc/rc.conf
/etc/resolv.conf
/etc/sysctl.conf
/etc/syslog.conf
/etc/ttys
/etc/shells
/etc/hosts*
/etc/*shrc
/etc/rc*
/var/cron/at.allow
/var/cron/at.deny
/var/cron/cron.allow
/var/cron/cron.deny
/etc/nsswitch.conf
"




#
#
# OpenBSD monitoring commands
#
#

# Function to obtain free memory
get_free_memory_openbsd () {
    MemFree=`vmstat | awk '/^([ \t]*[0-9]+)*$/ { print $5 }'`
    echo $MemFree    
}
# Function to obtain load average 
get_cpu_load_openbsd () {
    CpuLoad=`ps aux | awk 'BEGIN { cpu=0 }{ if (match($3,/[0-9].[0-9]/)) { cpu=cpu+$3 } } END { print cpu }'`
    echo $CpuLoad
}
# Function to obtain free disk space on /tmp
get_free_tmp_space_openbsd () {
    # Try to get free space in /tmp
    free_space_tmp=`df -P -k -l | awk '/\/tmp$/ { print $4 }'`

    # If it fails, try /
    if [ -z "$free_space_tmp" ]; then
        free_space_tmp=`df -P -k -l | awk '($NF == "/") { print $4 }'`
    fi

    echo "$free_space_tmp"
}


verify_resources


echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

PROCESSES="ps awwxo command"

get_shadow "$COPY_HASHES"

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt 2>&1
         fi

         echo -n "."
      else
         ls -la "$f" 1>> ./not-found.txt 2>&1
      fi
done
echo

cp /var/at/allow at.allow 2>> ./not-found.txt
cp /var/at/deny  at.deny 2>> ./not-found.txt
cp /var/cron/deny cron.deny 2>> ./not-found.txt 
cp /var/cron/allow cron.allow 2>> ./not-found.txt

lastlog > ./lastlog.txt  2>> ./not-found.txt

cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/.kshrc kshrc-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root  2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login csh.login-root 2>> ./not-found.txt


verify_resources


echo "[++] Searching permissions" >> $DEBUG_LOG
echo "[++] Searching permissions"
ls -l /etc/exports > exports_listagem.txt 2>> ./not-found.txt
collect_gcc_perms
[ -n "`which su`" ] && ls -lL `which su` 1> cc.txt 2>> ./not-found.txt
ls -ld `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u` >> home_listagem.txt 2>> ./not-found.txt
ls -ladL /tmp /var/tmp > tmps_listagem.txt 2>> ./not-found.txt
find /etc \( -type f -o -type d \) \( -perm -g=w -o -perm -o=w \) -exec ls -ld {} \; > etc_find.txt 2>/dev/null
ls -la /var/log > varlog_listagem.txt 2>> ./not-found.txt
ls -l /etc 1> etc_ls.txt 2>> ./not-found.txt

verify_resources



echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

dmesg > dmesg.txt 2>> ./not-found.txt
hostname > hostname.txt 2>> ./not-found.txt
id > id.txt 2>> ./not-found.txt 
ifconfig -a > ifconfig-a.txt 2>> ./not-found.txt 
netstat -na > netstat-na.txt 2>> ./not-found.txt
ps auxww > ps-auxww.txt 2>> ./not-found.txt
set > set.txt 2>> ./not-found.txt
sysctl -a > sysctl-a.txt 2>> ./not-found.txt
uname -a > uname.txt 2>> ./not-found.txt
w > w.txt 2>> ./not-found.txt
kldstat -v > kldstat.txt 2>> ./not-found.txt
pkg_info > pkginfo.txt 2>> ./not-found.txt
hostid > hostid.txt 2>> ./not-found.txt

verify_resources


echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"
find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \( -perm -4000 -o -perm -2000 \) -ls -fstype local > sid.txt

for h in `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u`; do
     [ -s $h/.netrc ] && {
           ls -ld $h/.netrc >> netrc.txt
     }

     [ -s $h/.rhosts ] && {
           ls -ld $h/.rhosts >> rhosts.txt
           cat $h/.rhosts >> rhosts.txt
     }
done


  ;;
Linux)
   echo "[+] Collecting Linux" >> $DEBUG_LOG
   echo "[+] Collecting Linux"
##############################################

SORT=`which sort 2>>./not-found.txt`
CHKCONFIG=`which chkconfig 2>>./not-found.txt`
SYSTEMCTL=`which systemctl 2>>./notfound.txt`
NETSTAT=`which netstat 2>>./not-found.txt`
SYSCTL=`which sysctl 2>>./not-found.txt`

CP_FILES="/etc/X11/gdm/gdm.conf
/etc/sysconfig
/etc/X11/xdm/Xaccess
/etc/aliases
/etc/cron.allow
/etc/at.allow
/etc/exports
/etc/fstab
/etc/group
/etc/inittab
/etc/lilo.conf
/etc/login.defs
/etc/motd
/etc/issue
/etc/passwd 
/etc/profile 
/etc/profile.local
/etc/bashrc
/etc/fedora-release
/etc/yellowdog-release 
/etc/SuSE-release
/etc/novell-release
/etc/debian_version
/etc/gentoo-release
/etc/redhat-release
/etc/conectiva-release
/etc/slackware-version
/etc/mandrake-release
/etc/resolv.conf
/etc/securetty
/etc/snmp/snmpd.conf
/etc/inetd.conf
/etc/sysconfig/authconfig
/etc/syslog.conf
/etc/rsyslog.conf
/etc/xinetd.conf
/etc/hosts*
/etc/conectiva-vers*o
/etc/vers*o-conectiva
/etc/sysctl.conf
/etc/ftpusers
/var/spool/cron/allow
/var/spool/cron/deny
/etc/logrotate.conf
/etc/nsswitch.conf
/etc/lsb-release
/etc/*-release
/etc/*_version
/usr/lib/systemd/system/rescue.service
/usr/lib/systemd/system/emergency.service
"

PROCESSES="ps awx -o command"




#
#
# Linux monitoring commands
#
#

# Function to obtain free memory
get_free_memory_linux () {
    MemFree=`cat /proc/meminfo | awk '/^MemFree:/ { print $2 }'`
    echo $MemFree    
}
# Function to obtain load average 
get_cpu_load_linux () {
    CpuLoad=`ps aux | awk 'BEGIN { cpu=0 }{ if (match($3,/[0-9].[0-9]/)) { cpu=cpu+$3 } } END { print cpu }'`
    echo $CpuLoad
}
# Function to obtain free disk space on /tmp
get_free_tmp_space_linux () {
    # Try to get free space in /tmp
    free_space_tmp=`df -P -l | awk '/\/tmp$/ { print $4 }'`

    # If it fails, try /
    if [ -z "$free_space_tmp" ]; then
        free_space_tmp=`df -P -l | awk '($NF == "/") { print $4 }'`
    fi

    echo "$free_space_tmp"
}

verify_resources


echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

get_shadow "$COPY_HASHES"

for f in $CP_FILES ; do
  if [ -f "$f" ] ; then
    cp "$f" . 2> /dev/null
    if [ $? -ne 0 ] ; then
      ls -la "$f" 1>> ./not-found.txt 2>&1
    fi
    echo -n "."       
  else      
    ls -la "$f" >> ./not-found.txt 2>&1
  fi
done

cp /etc/bash.bashrc ./bashrc 2>> ./not-found.txt

cp -R -L /etc/pam.d/su . 2>> ./not-found.txt
cp -R /etc/rc.d/ . 2>> ./not-found.txt
cp -R /etc/profile.d . 2>> ./not-found.txt
cp -R /etc/sysconfig . 2>> ./not-found.txt
cp -R /etc/rc.config.d/ 2>> ./not-found.txt

cp -R /etc/logrotate.d/ ./logrotate.d 2>>  ./not-found.txt
cp -R /etc/rsyslog.d/ ./rsyslog.d 2>>  ./not-found.txt
cp -R /etc/xinetd.d/ ./xinetd.d 2>> ./not-found.txt
cp -R /etc/inetd.d/ ./inetd.d 2>> ./not-found.txt
cp -R -L /etc/pam.d/ ./pam.d 2>> ./not-found.txt
cp -R /etc/event.d/ ./event.d 2>>  ./not-found.txt
cp -R /etc/init/ ./init 2>>  ./not-found.txt

cp ~root/.bash_profile ./bash_profile-root 2>> ./not-found.txt
cp ~root/.bashrc ./bashrc-root 2>> ./not-found.txt
cp ~root/.cshrc ./cshrc-root 2>> ./not-found.txt
cp ~root/.profile ./profile-root 2>> ./not-found.txt
cp ~root/.kshrc ./kshrc-root 2>> ./not-found.txt
cp ~root/.login ./login-root 2>> ./not-found.txt
cp ~root/.csh.cshrc ./csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login ./csh.login-root 2>> ./not-found.txt

mkdir -p security
cp /etc/security/limits.conf security/

mkdir -p boot/grub2
cp -R -L /boot/grub2/* boot/grub2 2>> not-found.txt
ls -l /boot/grub2/ 1> ls_grub2.txt 2>> not-found.txt

verify_resources


echo
echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

lsb_release -a > lsb_release-a.txt 2>> ./not-found.txt


if [ -n "$SYSTEMCTL" ]; then

	systemctl list-unit-files --type service > ./systemctl.txt 2>> ./not-found.txt
        systemctl status ctrl-alt-del.target >> ctrl-alt-del.target.txt
else

	if [ -n "$CHKCONFIG" ]; then

  		chkconfig --list > chkconfig.txt 2>> ./not-found.txt
	else

  		chkconfig_list
	fi
fi


if [ -n "$SYSCTL" ]; then

  sysctl -a > sysctl-a.txt 2>> ./not-found.txt

else

  gather_kernel_params

fi


hostname > hostname.txt 2>> ./not-found.txt 
id > id.txt 2>> ./not-found.txt 
ifconfig -a > ifconfig-a.txt 2>> ./not-found.txt
SPident -vvv > spident.txt 2>> ./not-found.txt

getenforce > getenforce.txt 2>> ./not-found.txt

if [ -n "$NETSTAT" ]; then

  netstat -na > netstat-na.txt 2>> ./not-found.txt

else

  cp --parents /proc/net/unix /proc/net/tcp /proc/net/tcp6 /proc/net/udp /proc/net/udp6 . 2>> ./not-found.txt

fi

hostid > hostid.txt 2>> ./not-found.txt
ps auxww > ps-auxww.txt 2>> ./not-found.txt 

rpm -qa > rpm-q-a.txt 2>> ./not-found.txt &
rpm -qa --qf "%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n" > rpm-q-f.txt 2>> ./not-found.txt &

kill_rpm "360"

set > set.txt 2>> ./not-found.txt
uname -a > uname.txt 2>> ./not-found.txt 
w > w.txt 2>> ./not-found.txt
who -r > who_r.txt 2>> ./not-found.txt
dpkg -l > dpkg-l.txt 2>> ./not-found.txt

lastlog > ./lastlog.txt  2>> ./not-found.txt

verify_resources

echo "[++] Searching permissions" >> $DEBUG_LOG
echo "[++] Searching permissions"

ls -l /etc/inetd.conf > inetd_perm.txt 2>> ./not-found.txt
ls -l /etc/lilo.conf > lilo_perm.txt 2>> ./not-found.txt
[ -n "`which su 2>>./not-found.txt`" ] && ls -lL `which su` 1> su_perm.txt 2>> ./not-found.txt
collect_gcc_perms 

home_dir_list=`get_home_directories "$SORT"`
printf "`ls -ld $home_dir_list 2>> ./not-found.txt`" >> home_listagem.txt

ls -lad /etc/xinetd.d /etc/xinetd.conf > xinetd_perm.txt 2>> ./not-found.txt
ls -ladL /tmp /var/tmp > tmps_listagem.txt 2>> ./not-found.txt
ls /var/log/packages > packages.txt 2>> ./not-found.txt
ls -la /var/log > varlog_listagem.txt 2>>./not-found.txt


verify_resources

echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"
find /dev /tmp /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -xdev \( -perm -4000 -o -perm -2000 \) -type f -ls > sid.txt
find /etc -xdev \( -type f -o -type d \) \( -perm -g=w -o -perm -o=w \) -exec ls -ld {} \; > etc_find.txt 2>/dev/null
ls -l /etc 1> etc_ls.txt 2>> ./not-found.txt

for h in $home_dir_list; do
  [ -s $h/.netrc ] && {
    ls -ld $h/.netrc >> netrc.txt
  }

  [ -s $h/.rhosts ] && {
    ls -ld $h/.rhosts >> rhosts.txt
    cat $h/.rhosts >> rhosts.txt
  }
done


verify_resources

################################################################################
#                                    VSFTPD                                    # 
################################################################################
mkdir vsftpd

vsftpd_via_default_path() {

  for conf in "/etc/vsftpd.conf /etc/vsftpd/vsftpd.conf"; do
    [ -f "$conf" ] && cp $conf ./vsftpd/ && return 0
  done

  return 1
}

vsftpd_via_processes() {
   proc_args=`ps auxww | grep "vsftpd" | grep -v "grep" | awk '{ for (i=12; i<=NF; i++) { print $i } }'`
   for arg in $proc_args; do
     [ -f "$arg" ] && cp $arg ./vsftpd/ && return 0
   done

   return 1
}

vsftpd_via_strings() {
  strings=`which strings 2>>./not-found.txt`
  [ -z "$strings" ] && return 1

  # Searching vsftpd binary on PATH or running processes
  bin=`which vsftpd 2>>./not-found.txt`
  [ -z "$bin" ] && bin=`ps auxww | grep "vsftpd" | grep -v "grep" | awk '{ print $11 }'`

  [ -f "$bin" ] && {
    possible_confs=`strings $bin | grep "\.conf"`
    for conf in $possible_confs; do
      [ -f "$conf" ] && cp $conf ./vsftpd/ && return 0
    done
  }

  return 1

}

vsftpd_via_default_path || vsftpd_via_processes || vsftpd_via_strings


################################################################################
#                                   PROFTPD                                    # 
################################################################################
mkdir proftpd

proftpd_via_default_path() {

  for conf in "/etc/proftpd.conf /etc/proftpd/proftpd.conf"; do
    [ -f "$conf" ] && cp $conf ./proftpd/ && return 0
  done

  return 1

}

proftpd_via_strings() {
  strings=`which strings 2>>./not-found.txt`
  [ -z "$strings" ] && return 1

  # Searching vsftpd binary on PATH
  bin=`which proftpd 2>>./not-found.txt`
  [ -z "$bin" ] && return 1

  [ -f "$bin" ] && {
    possible_confs=`strings $bin | grep "\.conf"`
    for conf in $possible_confs; do
      [ -f "$conf" ] && cp $conf ./proftpd/ && return 0
    done
  }

  return 1

}

proftpd_via_default_path || proftpd_via_strings


verify_resources




#Esse arquivo eh necessario para a analise de certos dispositivos (NetSec)
#Adicionado a pedido de Flavio Shinohara
[ -f "/etc/portslave/pslave.conf" ] && cp /etc/portslave/pslave.conf . 2>> ./not-found.txt

detect_grub () {

	grub_bin=`which grub 2>/dev/null`
	[ -z "$grub_bin" ] && {
	
		if [ -f "/sbin/grub" ]; then 

			grub_bin="/sbin/grub"
		else

			return #no grub binary has been found
		fi
	}

	grub_conf_file=`"$grub_bin" --help | awk ' $1 ~ /--config-file/ { print $NF }' | sed 's/[][]//g ; s/default\=//g'`
	[ -z "$grub_conf_file" ] && {

		grub_paths=`echo "/boot/grub/menu.lst /boot/grub/grub.conf /etc/grub.conf" | tr " " "\n"`
		for grub_path in ${grub_paths}; do

			[ -f "$grub_path" ] && { 
	
				grub_conf_file="$grub_path"
				break
			}
		done

		[ -z "$grub_conf_file" ] && return #no grub configuration file has been found
	}

	cat $grub_conf_file > grub.conf 2>>/not-found.txt
	ls -lL $grub_conf_file > grub_perm.txt 2>> ./not-found.txt
}

detect_grub

get_iptables_rules() {

        IPTABLES=`which iptables 2>>./not-found.txt`
        [ -n "$IPTABLES" ] && {

                detect_fw_modules=`lsmod | awk ' match($1,/^(ip_tables|iptable_(nat|filter)|nf_conntrack)$/) { print "firewall_enabled"; exit; }'`
                [ -z "$detect_fw_modules" ] && {

                        kernel_release=`uname -r`
                        builtin_file=`echo "/boot/config-$kernel_release"`

                        [ -f "$builtin_file" ] && builtin_fw_mod=`cat "$builtin_file" | awk -F'=' 'match($1,/^CONFIG_IP(6)?_NF_IPTABLES$/) && match($2,/^[yY]$/) { print "firewall_enabled"; exit; }'`
                }

                [ -n "$detect_fw_modules" -o -n "$builtin_fw_mod" ] && {

                        "$IPTABLES" -nL -v > ./iptables_nL_filter.txt 2>>./not-found.txt
                        "$IPTABLES" -t nat -nL -v > ./iptables_nL_nat.txt 2>>./not-found.txt
                        "$IPTABLES" -S > ./iptables_raw_rules.txt 2>>./not-found.txt
                }
        }
}

get_iptables_rules

  ;;
AIX)
   echo "[+] Collecting AIX" >> $DEBUG_LOG
   echo "[+] Collecting AIX"
CP_FILES="/etc/aliases
/etc/*.conf
/etc/environment
/etc/exports
/etc/group
/etc/hosts*
/etc/inetd.conf
/etc/inittab
/etc/issue
/etc/login*
/etc/motd
/etc/passwd*
/etc/profile
/etc/resolv.conf
/etc/services
/etc/*shrc
/etc/syslog.conf
/usr/dt/config/Xaccess
/var/adm/cron/*.allow
/etc/snmpd.conf
"

PROCESSES="ps -ef -o args"




#
#
# AIX monitoring commands
#
#

# Function to obtain free memory
get_free_memory_aix () {
    MemFree=`svmon | awk '/^memory/ { print $4 } '`
    echo $MemFree    
}

# Function to obtain load average 
get_cpu_load_aix () {
    CpuLoad=`ps aux | awk 'BEGIN { cpu=0 }{ if (match($3,/[0-9].[0-9]/)) { cpu=cpu+$3 } } END { print cpu }'`
    echo $CpuLoad
}
# Function to obtain free disk space on /tmp
get_free_tmp_space_aix () {
    # Try to get free space in /tmp
    free_space_tmp=`df -P -k | awk '/\/tmp$/ { print $4 }'`

    # If it fails, try /
    if [ -z "$free_space_tmp" ]; then
        free_space_tmp=`df -P -k | awk '($NF == "/") { print $4 }'`
    fi

    echo "$free_space_tmp"
}





verify_resources



echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"
for f in $CP_FILES; do
  if [ -f "$f" ]; then
    cp "$f" . 2> /dev/null
     if [ "$?" -ne 0 ]; then
       ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
     fi
     echo ".\c"
  else
    ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
  fi
done
echo

cp -R /etc/rc* .   2>> ./not-found.txt
mkdir -p security
cp /etc/security/passwd security/ 2>> ./not-found.txt
cp /etc/security/user security/ 2>> ./not-found.txt
cp /etc/security/login.cfg security/ 2>> ./not-found.txt

if [ $COPY_HASHES -ne 1 ]; then 
  [ -f "security/passwd" ] && {
    tmp_file=security/passwd.tmp
    cat security/passwd | sed "s/password.*/password = PASS/g" > $tmp_file
    cat $tmp_file > security/passwd
    rm $tmp_file
  }
fi

lastlog > ./lastlog.txt  2>> ./not-found.txt

cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/.kshrc kshrc-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root  2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login csh.login-root 2>> ./not-found.txt




verify_resources


echo "[++] Searching permissions" >> $DEBUG_LOG
echo "[++] Searching permissions"
ls -ldL /var/tmp /tmp 1> tmps_listagem.txt 2>> ./not-found.txt
ls -l /usr/bin/su 1> su_perm.txt  2>> ./not-found.txt
ls -l /etc 1> etc_ls.txt  2>> ./not-found.txt
collect_gcc_perms 
ls -ld `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u` >> home_listagem.txt  2>> ./not-found.txt
ls -la /var/adm 1> varadm_listagem.txt  2>> ./not-found.txt
ls -la /var/log 1> varlog_listagem.txt  2>> ./not-found.txt
find /etc \( -type f -o -type d \) \( -perm -g=w -o -perm -o=w \) -exec ls -ld {} \; > etc_find.txt 2>/dev/null
ls -l /etc/security 1> etc_security_ls.txt 2>> ./not-found.txt





verify_resources


echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"
ifconfig -a 1> ifconfig-a.txt  2>> ./not-found.txt
netstat -v 1> netstat-v.txt   2>> ./not-found.txt
netstat -nr 1> netstat-nr.txt 2>> ./not-found.txt
ps auxww 1> ps-auxww.txt  2>> ./not-found.txt
lssrc -a 1> lssrc-a.txt  2>> ./not-found.txt
instfix -i 1> patch.txt  2>> ./not-found.txt
oslevel -r 1> oslevel-r.txt 2>> ./not-found.txt
oslevel -s 1> oslevel-s.txt 2>> ./not-found.txt
lslpp -l 1> lslpp-l.txt 2>> ./not-found.txt
no -a 1> netsec.txt  2>> ./not-found.txt
hostname 1> hostname.txt  2>> ./not-found.txt
netstat -na 1> netstat-na.txt > netstat-na.txt
uname -a 1> uname.txt  2>> ./not-found.txt
set 1> set.txt  2>> ./not-found.txt
export 1> export.txt  2>> ./not-found.txt
id 1> id.txt  2>> ./not-found.txt
w > w.txt  2>> ./not-found.txt
hostid > hostid.txt 2>> ./not-found.txt




verify_resources


echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"
find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /bin /sbin -fstype jfs -type f -a \( -perm -4000 -o -perm -2000 \) -exec ls -l {} \; > sid.txt
find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /bin /sbin -fstype jfs2 -type f -a \( -perm -4000 -o -perm -2000 \) -exec ls -l {} \; >> sid.txt

for h in `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u`; do
  [ -s $h/.netrc ] && {
    ls -ld $h/.netrc >> netrc.txt
  }
  [ -s $h/.rhosts ] && {
    ls -ld $h/.rhosts >> rhosts.txt
    cat $h/.rhosts >> rhosts.txt
  }
done

  ;;
SunOS)
   echo "[+] Collecting SunOS" >> $DEBUG_LOG
   echo "[+] Collecting SunOS"
#################################################

CP_FILES="/etc/aliases
/etc/cron.d/at.allow
/etc/cron.d/cron.allow
/etc/dfs/dfstab
/etc/group
/etc/inetd.conf
/etc/motd
/etc/issue
/etc/passwd
/etc/profile
/etc/resolv.conf
/etc/system
/etc/vfstab
/etc/shells
/etc/mnttab
/etc/nsswitch.conf
/etc/ftp*
/etc/hosts*
/etc/*shrc
/etc/*.conf
"

#
#
# Solaris monitoring commands
#
#

# Function to obtain free memory
get_free_memory_sunos () {
	# Problems detected with versions of SunOS hanging on vmstat - function disabled
	# MemFree=`vmstat | /usr/xpg4/bin/awk '/^([ \t]*[0-9]+)*$/ { print $5 }'`
        MemFree="1000"
        echo $MemFree  
}

# Function to obtain load average 
get_cpu_load_sunos () {

    if [ -f "/usr/ucb/ps" ]; then

        CpuLoad=`/usr/ucb/ps aux | /usr/xpg4/bin/awk 'BEGIN { cpu=0 }{ if (match($3,/[0-9].[0-9]/)) { cpu=cpu+$3 } } END { print cpu }'`
    else

        CpuLoad=`/usr/bin/ps aux | /usr/xpg4/bin/awk 'BEGIN { cpu=0 }{ if (match($3,/[0-9].[0-9]/)) { cpu=cpu+$3 } } END { print cpu }'`
    fi

    echo $CpuLoad
}
# Function to obtain free disk space on /tmp
get_free_tmp_space_sunos () {
    # Try to get free space in /tmp
    free_space_tmp=`df -l -t -k | awk '/\/tmp$/ { print $4 }'`

    # If it fails, try /
    if [ -z "$free_space_tmp" ]; then
        free_space_tmp=`df -l -t -k | awk '($NF == "/") { print $4 }'`
    fi

    echo "$free_space_tmp"
}




verify_resources


echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

get_shadow "$COPY_HASHES"

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
         fi

         echo_n "."
      else
         ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
      fi
done
echo

mkdir ./security && cp -pf /etc/security/* ./security 2>> ./not-found.txt

if [ "$COPY_HASHES" -eq 0 -o ! -n "$COPY_HASHES" ]; then
	rm -f ./security/passhistory* 2>>./not-found.txt
fi

cp -pf /etc/pam*.conf . 2>> ./not-found.txt
cp -Rpf /etc/default . 2>> ./not-found.txt
cp -pRf /etc/rc2.d . 2>> ./not-found.txt
cp -pRf /etc/rc3.d . 2>> ./not-found.txt
cp /usr/dt/config/Xaccess Xaccess-usr 2>> ./not-found.txt
cp /etc/dt/config/Xaccess Xaccess-etc 2>> ./not-found.txt

lastlog > ./lastlog.txt  2>> ./not-found.txt

ROOTPWD=`grep '^root:' /etc/passwd | cut -d: -f6`
cp $ROOTPWD/.login login-root 2>> ./not-found.txt
cp $ROOTPWD/.bashrc bashrc-root 2>> ./not-found.txt
cp $ROOTPWD/.profile profile-root 2>> ./not-found.txt
cp $ROOTPWD/.kshrc kshrc-root 2>> ./not-found.txt
cp $ROOTPWD/.bash_profile bash_profile-root  2>> ./not-found.txt
cp $ROOTPWD/.cshrc cshrc-root 2>> ./not-found.txt
cp $ROOTPWD/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp $ROOTPWD/.csh.login csh.login-root 2>> ./not-found.txt

PROCESSES="ps -ef -o args"


verify_resources

echo "[++] Searching Permissions" >> $DEBUG_LOG
echo "[++] Searching Permissions"
ls -lL /var/adm/loginlog > loginlog_listagem.txt 2>> ./not-found.txt
ls -lL /var/adm/authlog > authlog_listagem.txt 2>> ./not-found.txt
[ -n "`which su 2>>./not-found.txt`" ] && ls -lL `which su` 1> su_perm.txt 2>> ./not-found.txt
collect_gcc_perms 
ls -ldL `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u` >> home_listagem.txt 2>> ./not-found.txt
ls -laL /var/adm > varadm_listagem.txt 2>> ./not-found.txt
ls -laL /var/log > varlog_listagem.txt 2>> ./not-found.txt
ls -ladL /etc/cron.d > cron.d_perm.txt 2>> ./not-found.txt
ls -ladL /tmp /var/tmp > tmps_listagem.txt 2>> ./not-found.txt
ls -ldL /etc/notrouter > notrouter_listagem.txt 2>> ./not-found.txt

find /etc \( -type f -o -type d \) \( -perm -g=w -o -perm -o=w \) -exec ls -ld {} \; > etc_find.txt 2>/dev/null
ls -l /etc 1> etc_ls.txt 2>> ./not-found.txt
hostid > hostid.txt 2>> ./not-found.txt


verify_resources

echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

dmesg > dmesg.txt  2>> ./not-found.txt
domainname > domainname.txt  2>> ./not-found.txt
hostname > hostname.txt  2>> ./not-found.txt
id > id.txt  2>> ./not-found.txt
ifconfig -a > ifconfig-a.txt  2>> ./not-found.txt
passwd -sa > passwd-sa.txt  2>> ./not-found.txt

solaris_11_and_above=`uname -a | awk '{ print $3 }' | awk -F'.' '{ print $2 }'`

if [ "$solaris_11_and_above" -le "10" ]; then

        ndd -get /dev/ip ip_respond_to_timestamp > respond_to_timestamp_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/ip ip_forward_directed_broadcasts > directed_broadcasts_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/ip ip_forward_src_routed > src_routed_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/ip ip_forwarding > ip_forwarding_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/ip ip_ignore_redirect > ignore_redirect_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/ip ip_respond_to_echo_broadcast > echo_broadcast_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/ip ip_respond_to_timestamp_broadcast > timestamp_broadcast_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/tcp tcp_sack_permitted > sack_permitted_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/tcp tcp_ip_abort_cinterval > ip_abort_cinterval_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/tcp tcp_conn_req_max_q > conn_req_max_q_ndd.txt  2>> ./not-found.txt
        ndd -get /dev/tcp tcp_conn_req_max_q0 > conn_req_max_q0_ndd.txt  2>> ./not-found.txt
else

        ipadm show-prop -p _respond_to_timestamp -co current ip > respond_to_timestamp_ndd.txt  2>> ./not-found.txt
        ipadm show-prop -p _forward_directed_broadcasts -co current ip > directed_broadcasts_ndd.txt  2>> ./not-found.txt
        ipadm show-prop -p _forward_src_routed -co current ipv4 > src_routed_ndd_ipv4.txt  2>> ./not-found.txt
        ipadm show-prop -p _forward_src_routed -co current ipv6 > src_routed_ndd_ipv6.txt  2>> ./not-found.txt
        ipadm show-prop -p _ignore_redirect -co current ipv4 > ignore_redirect_ndd_ipv4.txt  2>> ./not-found.txt
        ipadm show-prop -p _ignore_redirect -co current ipv6 > ignore_redirect_ndd_ipv6.txt  2>> ./not-found.txt
        ipadm show-prop -p send_redirects -co current ipv4 > send_redirects_ipv4.txt  2>> ./not-found.txt
        ipadm show-prop -p send_redirects -co current ipv6 > send_redirects_ipv6.txt  2>> ./not-found.txt
        ipadm show-prop -p _rev_src_routes tcp -co current > rev_src_routes.txt 2>> ./not-found.txt
        ipadm show-prop -p _respond_to_echo_broadcast -co current ip > echo_broadcast_ndd.txt  2>> ./not-found.txt
        ipadm show-prop -p _respond_to_timestamp_broadcast -co current ip > timestamp_broadcast_ndd.txt  2>> ./not-found.txt
        ipadm show-prop -p sack tcp -co current > sack_permitted_ndd.txt  2>> ./not-found.txt
        ipadm show-prop -p _strong_iss tcp -co current > strong_iss.txt 2>> ./not-found.txt
        ipadm show-prop -p _respond_to_address_mask_broadcast ip -co current > respond_to_address_mask_broadcast.txt 2>> ./not-found.txt
        ipadm show-prop -p _respond_to_echo_multicast ipv4 -co current > respond_to_echo_multicast_ipv4.txt 2>> ./not-found.txt
        ipadm show-prop -p _respond_to_echo_multicast ipv6 -co current > respond_to_echo_multicast_ipv6.txt 2>> ./not-found.txt

        routeadm -p ipv4-forwarding > ip_forwarding_ndd_ipv4.txt  2>> ./not-found.txt
        routeadm -p ipv4-routing > ip_routing_ndd_ipv4.txt  2>> ./not-found.txt
        routeadm -p ipv6-forwarding > ip_forwarding_ndd_ipv6.txt  2>> ./not-found.txt
        routeadm -p ipv6-routing > ip_routing_ndd_ipv6.txt  2>> ./not-found.txt

        svccfg -s svc:/system/system-log listprop config/log_from_remote | awk '{ print $NF }' > remote_syslog_stats.txt 2>> ./not-found.txt
        svccfg -s keymap:default listprop keymap/keyboard_abort | awk '{ print $NF }' > keyboard_abort_stats.txt 2>> ./not-found.txt

        coreadm > coreadm_stats.txt 2>> ./not-found.txt
        coreadm_dir=`awk -F':' ' $0 ~ /global[ ]+core file pattern/ { print $2 }' ./coreadm_stats.txt 2>>./not-found.txt | awk -F'/' '{ OFS="/"; $NF=""; print $0 }' | sed 's/ //g'`
        if [ -n "$coreadm_dir" ]; then
                ls -ld "$coreadm_dir" > var_cores_perm.txt 2>> ./not-found.txt
        else
                touch var_cores_perm.txt
        fi

        svcs -Ho state svc:/system/console-login:terma > console_logina_stats.txt 2>> ./not-found.txt
        svcs -Ho state svc:/system/console-login:termb > console_loginb_stats.txt 2>> ./not-found.txt

        grub_conf_file="/rpool/boot/grub/grub.cfg"
        cp -p "$grub_conf_file" . 2>> ./not-found.txt
        ls -lL "$grub_conf_file" > grub_perm.txt 2>> ./not-found.txt
        eeprom security-mode | awk -F= '{ print $2 }' > eeprom_security_mode.txt 2>> ./not-found.txt
        eeprom security-\#badlogins | awk -F= '{ print $2 }' > eeprom_security_badlogins.txt 2>> ./not-found.txt
fi

netstat -na > netstat-na.txt  2>> ./not-found.txt
netstat -nr > netstat-nr.txt  2>> ./not-found.txt
ps -ef > ps-ef.txt  2>> ./not-found.txt

PS_COMMAND="$PS_SUNOS"
[ -n "$PS_COMMAND" ] && eval "$PS_COMMAND" > ps-auxwww.txt 2>> ./not-found.txt

set > set.txt  2>> ./not-found.txt
showrev -p > showrev.txt  2>> ./not-found.txt
showrev -p  2>> ./not-found.txt | cut -f2 -d  ' ' > patches.txt
pkginfo > pkginfo.txt  2>> ./not-found.txt
pkginfo -x > pkginfo-x.txt  2>> ./not-found.txt
uname -a > uname.txt  2>> ./not-found.txt
lpstat -a > lpstat.txt  2>> ./not-found.txt
w > w.txt  2>> ./not-found.txt
svcs > svcs.txt 2>> ./not-found.txt

inet=`which inetadm 2>> ./not-found.txt`

if [ -n "$inet" ]; then
     inetadm -p > inetadm-default.txt
     inetadm > inetadm.txt 2>> ./not-found.txt

     for service in `inetadm | awk ' /svc:/ { print $3 } '`; do
          echo "$service" >> inetadm-complete.txt
          inetadm -l "$service" >> inetadm-complete.txt
     done
fi


verify_resources

echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"
find /usr/ccs/bin /usr/ucb /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \( -perm -4000 -o -perm -2000 \) -ls > sid.txt 2>> ./not-found.txt

for h in `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u`; do
     [ -s $h/.netrc ] && {
           ls -ld $h/.netrc >> netrc.txt
     }
     [ -s $h/.rhosts ] && {
           ls -ld $h/.rhosts >> rhosts.txt
           cat $h/.rhosts >> rhosts.txt
     }
done

solaris_version=`uname -r | sed -n 's/[0-9]\.\([0-9]\{1,\}\)/\1/p'`
[ "$solaris_version" -eq "10" ] && {

  zoneadm list -vc > zoneadm_list_-vc.out
  prtdiag > prtdiag.out 2> prtdiag.err
  echo $? > prtdiag.exit_code

}

  ;;
HP-UX)
   echo "[+] Collecting HP-UX" >> $DEBUG_LOG
   echo "[+] Collecting HP-UX"
###################################################

TRUSTED_FLAG="4"

CP_FILES="/etc/netconfig
/etc/netgroup
/etc/group
/etc/networks
/etc/pam.conf
/etc/SnmpAgent.d/snmpd.conf
/etc/snmpd.conf
/etc/securetty
/sbin/rc
/etc/services
/etc/inetd.conf
/etc/motd
/etc/profile
/etc/inittab
/etc/resolv.conf
/etc/nsswitch.conf
/etc/aliases
/etc/syslog.conf
/etc/login*
/etc/exports
/etc/hosts*
/etc/*shrc
/etc/*.conf
/etc/issue*
/var/adm/cron/*.allow
/usr/dt/config/Xaccess
/etc/xtab
"


#
#
# HP-UX monitoring commands
#
#

# Function to obtain free memory
get_free_memory_hpux () {
    MemFree=`vmstat | awk '/^([ \t]*[0-9]+)*$/ { print $5 }'`
    echo $MemFree    
}
# Function to obtain load average 
get_cpu_load_hpux () {
    CpuLoad=`ps -ef | awk 'BEGIN { cpu=0 }{ if (match($4,/[0-9]/)) { cpu=cpu+$4 } } END { print cpu }'`
    echo $CpuLoad
}
# Function to obtain free disk space on /tmp
get_free_tmp_space_hpux () {
    # Try to get free space in /tmp
    free_space_tmp=`df -P -k -l | awk '/\/tmp$/ { print $4 }'`

    # If it fails, try /
    if [ -z "$free_space_tmp" ]; then
        free_space_tmp=`df -P -k -l | awk '($NF == "/") { print $4 }'`
    fi

    echo "$free_space_tmp"
}



verify_resources


PROCESSES="ps -ef | sed -n \"s/.*[0-9]:[0-9]* \(.*\)$/\1/p\""

echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
         fi

         echo ".\c"
      else
         ls -la "$f" 1>> ./not-found.txt 2>> ./not-found.txt
      fi
done
echo

cp -r /tcb . 2>> ./not-found.txt
cp -r /sbin/init.d . 2>> ./not-found.txt
cp -rf /etc/rc.config.d . 2>> ./not-found.txt
cp -rf /etc/default . 2>> ./not-found.txt

lastlog > ./lastlog.txt  2>> ./not-found.txt

cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/.kshrc kshrc-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root  2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login csh.login-root 2>> ./not-found.txt


verify_resources



echo "[++] Searching Permissions" >> $DEBUG_LOG
echo "[++] Searching Permissions"
ls -ladL /var/tmp /tmp > tmps_listagem.txt 2>> ./not-found.txt
ls -l /usr/bin/su > su_perm.txt 2>> ./not-found.txt

find /etc \( -type f -o -type d \) \( -perm -g=w -o -perm -o=w \) -exec ls -ld {} \; > etc_find.txt 2>/dev/null
ls -l /etc > etc_ls.txt 2>> ./not-found.txt
collect_gcc_perms 
ls -ld `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u` >> home_listagem.txt  2>> ./not-found.txt
ls -la /var/adm  > varadm_listagem.txt 2>> ./not-found.txt
ls -la /var/log  > varlog_listagem.txt 2>> ./not-found.txt


verify_resources


echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

getprivgrp > privgroup.txt 2>> ./not-found.txt
lanscan -v > lanscan-v.txt 2>> ./not-found.txt
for interface in `lanscan -i`; do ifconfig $interface > ifconfig-$interface.txt; done
swlist -l fileset -a supersedes -a revision -a software_spec -a state > patch_security.txt 2>> ./not-found.txt
sysdef > sysdef.txt  2>> ./not-found.txt
kmtune > kmtune.txt  2>> ./not-found.txt
kmsystem > kmsystem.txt  2>> ./not-found.txt
swlist > swlist.txt  2>> ./not-found.txt
swlist -l patch > swlist-patch.txt  2>> ./not-found.txt
swlist -a revision -l fileset > swlist-revision.txt  2>> ./not-found.txt
what /stand/vmunix >  what-vmunix.txt  2>> ./not-found.txt
ps -ef > ps-ef.txt  2>> ./not-found.txt
ps -el > ps-el.txt  2>> ./not-found.txt
hostname > hostname.txt  2>> ./not-found.txt
netstat -na > netstat-na.txt  2>> ./not-found.txt
uname -a > uname.txt  2>> ./not-found.txt
set > set.txt  2>> ./not-found.txt
export > export.txt  2>> ./not-found.txt
id > id.txt  2>> ./not-found.txt
w > w.txt  2>> ./not-found.txt
hostid > hostid.txt 2>> ./not-found.txt

passwd -sa > passwd-sa.txt  2>> ./not-found.txt
ndd -get /dev/ip ip_forwarding > ip_forwarding.txt 2>> ./not-found.txt
ndd -get /dev/tcp tcp_syn_rcvd_max > tcp_syn_rcvd_max.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_forward_directed_broadcasts > ip_forward_directed_broadcasts.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_echo_broadcast > ip_respond_to_echo_broadcast.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_timestamp > ip_respond_to_timestamp.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_timestamp_broadcast > ip_respond_to_timestamp_broadcast.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_address_mask_broadcast > ip_respond_to_address_mask_broadcast.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_forward_src_routed > ip_forward_src_routed.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_send_redirects > ip_send_redirects.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_pmtu_strategy > ip_pmtu_strategy.txt 2>> ./not-found.txt
ndd -get /dev/arp arp_cleanup_interval > arp_cleanup_interval.txt 2>> ./not-found.txt

#getprpw root > ./prpw.root
/usr/lbin/getprpw root > ./prpw.root
trusted_flag=`echo $?`
printf "$trusted_flag\n" > trusted_flag.txt

if [ $COPY_HASHES -eq 1 ]; then

	for passwd_file in `ls /etc/passwd*`; do
    
		cp "$passwd_file" .
  	done

	for shadow_file in `ls /etc/shadow*`; do
    
		cp "$shadow_file" .
  	done

else

	[ -f "/etc/passwd" ] && {

		#Copying passwd without password hashes
		cp /etc/passwd .
		cat passwd | awk -F: '{ if ($2 ~ /\*(\*)?$|\!(\!)?$|x$/) { print $0 } else { OFS=":"; $2="HASH"; print $0 }; }' >./passwd.temp
       		mv ./passwd.temp ./passwd
	}

  	if [ "$trusted_flag" != "$TRUSTED_FLAG" ]; then
   
   		#Removing password hashes from /tcp/files/auth copied files
   		for dir in `ls tcb/files/auth`; do
      
			[ "$dir" = "system" ] && continue
      			for file in `ls tcb/files/auth/$dir`; do
        
				tmpfile=`mktemp`
        			file=tcb/files/auth/$dir/$file
        			sed "/[ \t]\{0,\}:u_pwd=/d" $file > $tmpfile
        			cat $tmpfile > $file
        			rm $tmpfile
      			done
   		done

  		#Removing the history hashes information
  		rm -rf tcb/files/auth/system/pwhist/* 2>/dev/null
  	else

		[ -f "/etc/shadow" ] && {

			#Copying shadow without password hashes
			cp /etc/shadow .
			cat shadow | awk -F: '{ if ($2 ~ /\*(\*)?$|\!(\!)?$|x$/) { print $0 } else { OFS=":"; $2="HASH"; print $0 }; }' >./shadow.temp
        		mv ./shadow.temp ./shadow
		}
  	fi

fi

verify_resources

echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"
LIST_SUIDS="/usr/bin
/usr/sbin
/usr/local/bin
/usr/local/sbin
/bin
/sbin
"

for i in $LIST_SUIDS; do
    [ -d $i ] && SIDPATH="$i $SIDPATH"; 
done

find $SIDPATH -fsonly hfs -fsonly vxfs -type f -a \( -perm -4000 -o -perm -2000 \) -exec ls -l {} \; > sid.txt

if [ -x /usr/lbin/modprpw ]; then
   PATH=$PATH:/usr/lbin
   export PATH

   modprpw 1> /dev/null 2>&1
   
   if [ $? -eq 2 ]; then
       getprdef -r 1> prdef.txt 2>&1
       mkdir "trusted"

       for user in `cut -d: -f1 /etc/passwd`; do
            getprpw -r $user >> "trusted/prpw_$user"        
       done
   fi
fi

for h in `grep -v "^#" /etc/passwd | cut -d: -f6 | sort -u`; do
     [ -s $h/.netrc ] && {
         ls -ld $h/.netrc >> netrc.txt
     }
     [ -s $h/.rhosts ] && {
        ls -ld $h/.rhosts >> rhosts.txt
        cat $h/.rhosts >> rhosts.txt
     }
done


ls -l /var/spool/cron/crontabs/* > crontab_users.txt
  ;;
QNX)
   echo "[+] Collecting QNX" >> $DEBUG_LOG
   echo "[+] Collecting QNX"
  ;;
Darwin)
   echo "[+] Collecting Darwin" >> $DEBUG_LOG
   echo "[+] Collecting Darwin"
########################################################
# COMMON
########################################################
PROCESSES="ps awwxo command"
########################################################

########################################################
# Checking if that system is Leopard or not
########################################################
darwin_version=`sw_vers | awk ' match($0,/^[ \t]*ProductVersion/) { print $2 } ' | cut -d. -f1`
darwin_subversion=`sw_vers | awk ' match($0,/^[ \t]*ProductVersion/) { print $2 } ' | cut -d. -f2`

#############################
# It is a Leopard System or higher
#############################
if [ "$darwin_version" -ge "10" -a "$darwin_subversion" -ge 5 ] || [ "$darwin_version" -ge "11" ]; then

/usr/bin/sw_vers > sw_vers.txt 2>/dev/null

#################################################
# Files to be copied
#################################################
CP_FILES="
/usr/lib/cron/cron.deny
/usr/lib/cron/cron.allow
/usr/lib/cron/at.deny
/usr/lib/cron/at.allow
/etc/authorization
/etc/exports
/etc/fstab
/etc/ftpusers
/etc/group
/etc/hostconfig
/etc/inetd.conf
/etc/inittab
/etc/master.passwd 
/etc/profile
/etc/resolv.conf
/etc/syslog.conf
/etc/ttys
/etc/shells
/etc/ftp*
/etc/hosts
/etc/passwd
/etc/*shrc
/etc/motd
/etc/issue
/etc/issue.net
"
#################################################

echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt 2>&1
         fi

         echo_n "."
      else
         ls -la "$f" 1>> ./not-found.txt 2>&1
      fi
done
echo

cp -r /etc/pam.d .

#################################################
# Profiles for root
#################################################
cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/.kshrc kshrc-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root  2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login csh.login-root 2>> ./not-found.txt
#################################################

echo "[++] Searching Permissions" >> $DEBUG_LOG
echo "[++] Searching Permissions"

#################################################
# File permissions and logging
#################################################
ls -l /usr/bin/su > su.txt
ls -l /etc/ > etc_ls.txt
ls -l /var/log/ > log.txt
lastlog > ./lastlog.txt  2>> ./not-found.txt
collect_gcc_perms
ls -la /var/log > varlog_listagem.txt 2>> ./not-found.txt
ls -lad /tmp /var/tmp > tmps_listagem.txt
find /var/log -perm +0066 -ls |grep -v lrwxrwxrwx > varlog_find.txt
find /etc -perm -0002 \( -type f -o -type d \) -exec ls -ld {} \; > etc_find.txt 2>>./not-found.txt
#################################################

echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

#################################################
# System information and networking
#################################################
uname -a > uname.txt  2>> ./not-found.txt
df -k > df.txt 2>&1
domainname > domainname.txt 2>&1
hostname > hostname.txt 2>&1
ifconfig -a > ifconfig-a.txt 2>> ./not-found.txt
ps auxwww > ps-auxwww 2>&1
defaults read /Library/Preferences/com.apple.alf globalstate >./fw_status.txt 2>>./not-found.txt
spctl --status 2>>./not-found.txt | awk '{ print $2 }' >./app_fw_status.txt 
defaults read /Library/Preferences/com.apple.Bluetooth ControllerPowerState >./bluetooth_status.txt 2>>./not-found.txt
defaults read /Library/Preferences/com.apple.driver.AppleIRController DeviceEnabled >./ircontroller_status.txt 2>>./not-found.txt

defaults read /Library/Preferences/com.apple.virtualMemory UseEncryptedSwap >./swap_status.txt 2>>./not-found.txt
sysctl vm.swapusage >swap_status2.txt 2>>./not-found.txt
ls -dl /System/Library/Extensions/IOUSBMassStorageClass.kext >./usb_storage.txt 2>>./not-found.txt
defaults read /Library/Preferences/com.apple.loginwindow SHOWFULLNAME >./logon_userlisting.txt 2>>./not-found.txt
defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText >./logon_banner.txt 2>>./not-found.txt

if [ -f "/etc/authorization" ]; then

	/usr/libexec/PlistBuddy -c "Print :rights:system.preferences:shared" /etc/authorization > ./sys_pref_admin_restrict_status.txt 2>>./not-found.txt
else

	security authorizationdb read system.preferences > ./.system.preferences.plist
	/usr/libexec/PlistBuddy -c "Print :shared" ./.system.preferences.plist > ./sys_pref_admin_restrict_status.txt 2>>./not-found.txt
	rm -f ./.system.preferences.plist
fi


defaults read /Library/Preferences/com.apple.SoftwareUpdate > ./software_update.txt 2>> ./not-found.txt
pmset -g everything | grep -c 'powernap             1' > ./powernap_status.txt 2>> ./not-found.txt

if_config=`ifconfig | egrep -o "^[a-zA-Z0-9]+"`
for i in $if_config; do
        networksetup -getairportpower $i >> ./airport_status.txt 2>> ./not-found.txt
done

if ([ "$darwin_version" = 10 ] && [ "$darwin_subversion" -ge 14 ]) || [ "$darwin_version" -ge 11 ]; then
        defaults read /Library/Preferences/com.apple.loginwindow | grep autoLoginUser | awk -F"=" '{ print $2 }' > ./autologin_status.txt 2>> ./not-found.txt
else
        /usr/libexec/PlistBuddy -c "Print" /Library/Preferences/com.apple.loginwindow.plist | grep autoLoginUser | awk -F"=" '{ print $2 }' > ./autologin_status.txt 2>>./not-found.txt
fi

defaults read /Library/Preferences/com.apple.commerce AutoUpdate > ./auto_update.txt 2>> ./not-found.txt

defaults read /Library/Preferences/com.apple.SoftwareUpdate | egrep "(ConfigDataInstall|CriticalUpdateInstall)" > ./software_security_update.txt 2>> ./not-found.txt

/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode > ./stealth_mode.txt 2>> ./not-found.txt

launchctl list | egrep ftp > ./ftp_status.txt 2>> ./not-found.txt

ps -ef  | grep -v "grep -i nfsd" | grep -i nfsd > ./nfs_status.txt 2>> ./not-found.txt

ps -ef  | egrep -v "egrep ARDAgent" | egrep ARDAgent > ./ardagent_status.txt 2>> ./not-found.txt

launchctl list | grep -i auditd  > ./security_audit_status.txt 2>> ./not-found.txt

systemsetup -getusingnetworktime > ./ntp_status.txt 2>> ./not-found.txt

systemsetup -getremoteappleevents > ./apple_remote_events.txt 2>> ./not-found.txt

defaults read /Library/Preferences/SystemConfiguration/com.apple.nat | grep -i Enabled > ./internet_sharing.txt 2>> ./not-found.txt

launchctl list | grep -i com.apple.screensharing > ./screensharing.txt 2>> ./not-found.txt

system_profiler SPPrintersDataType | grep -i "shared: yes" > ./printer_sharing.txt 2>> ./not-found.txt

launchctl list | egrep ODSAgent > ./dvd_cd_sharing.txt 2>> ./not-found.txt

launchctl list | egrep "(AppleFileServer|com.apple.smbd)" > ./file_sharing.txt 2>> ./not-found.txt

pmset -g | egrep womp > ./wake_status.txt 2>> ./not-found.txt

fdesetup status > ./filevault_status.txt 2>> ./not-found.txt

defaults read NSGlobalDomain AppleShowAllExtensions > ./appleshowallextensions.txt 2>> ./appleshowallextensions.txt

#################################################

#################################################
# Users and Groups List
#################################################

ls -l /Users/ > ./ls-l_Users.txt 2>> ./not-found.txt

defaults read /Library/Preferences/com.apple.loginwindow.plist | egrep "GuestEnabled" >./guestenabled.txt 2>>./not-found.txt
defaults read /Library/Preferences/com.apple.AppleFileServer | grep -i guest>./guestaccess.txt 2>>./not-found.txt

dsexport ./groups.txt /Local/Default dsRecTypeStandard:Groups 2>>./not-found.txt
dsexport ./users.txt.temp /Local/Default dsRecTypeStandard:Users 2>>./not-found.txt

get_shadow "$COPY_HASHES"

if [ "$COPY_HASHES" -eq 0 ]; then
	sed "s/SHA.\{46\}/PASS\;/g" ./users.txt.temp > ./users.txt 2>>./not-found.txt
	rm -f users.txt.temp
else
	mv users.txt.temp users.txt
fi
#################################################

#################################################
# Password Policy and other items
#################################################
mkdir -p password_policy
mkdir -p bluetooth_restrictions
mkdir -p screensaver/{status,require_password}
mkdir -p safari_autoopen
mkdir -p corner

firmwarepasswd -check >./password_policy/firmwarepasswdcheck.txt 2>>./not-found.txt
defaults read /Library/Preferences/com.apple.loginwindow RetriesUntilHint >./password_policy/retriesuntilhint.txt 2>>./not-found.txt

pwpolicy -n /Local/Default -getglobalpolicy >./password_policy/default.txt 2>>./not-found.txt
defaults read /Library/Preferences/com.apple.loginwindow PasswordExpirationDays >./password_policy/global_password_warning.txt 2>>./not-found.txt
UUID=`ioreg -rd1 -c IOPlatformExpertDevice | grep "IOPlatformUUID" | sed -e 's/^.* "\(.*\)"$/\1/'`

users=`cat users.txt | awk -F: '{ print $3":"$6 }' | egrep "\/(ba|(t)?c|z|k)?sh$" | cut -d: -f1 | cut -d, -f1`
[ -z "$users" ] && users=`cat users.txt | awk -F: '{ print $3":"$8 }' | egrep "\/(ba|(t)?c|z|k)?sh$" | cut -d: -f1 | cut -d, -f1`
for user in ${users}; do
	#Password policy
	pwpolicy -n /Local/Default -getpolicy -u $user >./password_policy/$user.txt 2>>./not-found.txt

	#Bluetooth restrictions
	su - $user -c "defaults -currentHost read com.apple.bluetooth PrefKeyServicesEnabled" >./bluetooth_restrictions/$user.txt 2>>./not-found.txt

	#Screensaver properties
        if ([ "$darwin_version" = 10 ] && [ "$darwin_subversion" -ge 14 ]) || [ "$darwin_version" -ge 11 ]; then
                PREF=/Users/$user/Library/Preferences/ByHost/com.apple.screensaver.$UUID
                if [ -e $PREF.plist ]; then
                        defaults read $PREF.plist idleTime > ./screensaver/status/$user.txt 2>> ./not-found.txt
                        defaults read $PREF.plist askForPassword > ./screensaver/require_password/$user.txt 2>> ./not-found.txt
                fi
        else
                su - $user -c "defaults -currentHost read com.apple.screensaver idleTime" > ./screensaver/status/$user.txt 2>> ./not-found.txt
                su - $user -c "defaults read com.apple.screensaver askForPassword" > ./screensaver/require_password/$user.txt 2>> ./not-found.txt
        fi

	#Safari - opening files automatically
        if ([ "$darwin_version" = 10 ] && [ "$darwin_subversion" -ge 14 ]) || [ "$darwin_version" -ge 11 ]; then
                defaults read /Users/$user/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari AutoOpenSafeDownloads > ./safari_autoopen/$user.txt 2>> ./not-found.txt
        else
                defaults read /Users/$user/Library/Preferences/com.apple.Safari AutoOpenSafeDownloads > ./safari_autoopen/$user.txt 2>> ./not-found.txt
        fi

        defaults read /Users/$user/Library/Preferences/com.apple.dock | grep -i corner > ./corner/$user.txt 2>> ./not-found.txt
done
#################################################

#################################################
# SUIDs
#################################################
echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"

find /usr/ccs/bin /usr/ucb /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \( -perm -4000 -o -perm -2000 \) -ls 1>> sid.txt 2>>./not-found.txt
find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -perm +6000 -ls 1>> sid.txt 2>>./not-found.txt
#################################################

else
#############################
# It is not a Leopard System
#############################

/usr/bin/sw_vers > sw_vers.txt 2>/dev/null

CP_FILES="/var/at/at.allow
/var/at/at.deny
/etc/exports
/etc/fstab
/etc/ftpusers
/etc/group
/etc/hostconfig
/etc/inetd.conf
/etc/inittab
/etc/master.passwd 
/etc/profile
/etc/resolv.conf
/etc/syslog.conf
/etc/ttys
/etc/shells
/etc/ftp*
/etc/hosts*
/etc/passwd*
/etc/*shrc
/etc/issue*
"

echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt 2>&1
         fi

         echo_n "."
      else
         ls -la "$f" 1>> ./not-found.txt 2>&1
      fi
done
echo

cp -r /etc/pam.d .
cp /var/cron/allow cron.allow
cp /var/cron/deny cron.deny
cp -Rpf /etc/rc* .

lastlog > ./lastlog.txt  2>> ./not-found.txt

cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/.kshrc kshrc-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root  2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/.csh.login csh.login-root 2>> ./not-found.txt

echo "[++] Searching Permissions" >> $DEBUG_LOG
echo "[++] Searching Permissions"

ls -l /usr/bin/su > su.txt
ls -l /etc 1> etc_ls.txt
ls -l /etc > etc.txt
ls -l /etc/exports > exports_listagem.txt
ls -l /etc/inetd.conf > inetd_perm.txt
ls -l /var/log > log.txt
collect_gcc_perms
ls -la /var/cron/tabs > crontabs_listagem.txt
ls -la /var/log > varlog_listagem.txt 2>> ./not-found.txt
ls -lad /etc/cron.d > cron.d_perm.txt
ls -lad /etc/xinetd.d /etc/xinetd.conf > xinetd_perm.txt
ls -lad /tmp /var/tmp > tmps_listagem.txt
ls -ld /tmp > tmp.txt
ls -ld /var/tmp >> tmp.txt
find /var/log -perm +0066 -ls |grep -v lrwxrwxrwx > varlog_find.txt
find /etc -perm -0002 \( -type f -o -type d \) -exec ls -ld {} \; > etc_find.txt
hostid > hostid.txt 2>> ./not-found.txt

echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

uname -a > uname.txt  2>> ./not-found.txt
df -k > df.txt 2>&1
dmesg > dmesg.txt 2>&1
domainname > domainname.txt 2>&1
hostname > hostname.txt 2>&1
ps auxwww > ps-auxwww 2>&1

niutil -list . /users > niutil-users.txt 2>> ./not-found.txt
niutil -list . /groups > niutil-groups.txt 2>> ./not-found.txt
nidump passwd . / > nidump-passwd.txt 2>> ./not-found.txt
nidump group . / > nidump-group.txt 2>> ./not-found.txt
ifconfig -a > ifconfig-a.txt 2>> ./not-found.txt

for user in `nidump group / / | egrep "^admin:" | cut -f4- -d":" | tr "," " "`; do 
      ls -ld "`niutil -read / /users/$user | egrep home | cut -f2- -d" "`"; 
done > admins_listagem.txt

get_shadow "$COPY_HASHES"

for user in `nidump passwd / / | cut -f1 -d":"` ; do 
       ls -ld "`niutil -read / /users/$user | egrep home | cut -f2- -d" "`"; 
done > home_listagem.txt


for user in `nidump passwd / / | cut -f1 -d":"`; do
     h=`niutil -read / /users/$user | egrep home | cut -f2- -d" "`
     [ -s $h/.netrc ] && {
          ls -ld $h/.netrc >> netrc.txt
     }
     [ -s $h/.rhosts ] && {
          ls -ld $h/.rhosts >> rhosts.txt
          cat $h/.rhosts >> rhosts.txt
     }
done

echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"

find /usr/ccs/bin /usr/ucb /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \( -perm -4000 -o -perm -2000 \) -ls >> sid.txt
find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -perm +6000 -ls >> sid.txt

#################################################
fi
#################################################
  ;;
*)
   echo "[+] Collecting *" >> $DEBUG_LOG
   echo "[+] Collecting *"

SORT=`which sort`
CHKCONFIG=`which chkconfig`
NETSTAT=`which netstat`
SYSCTL=`which sysctl`

CP_FILES="/boot/defaults/loader.conf
/etc/X11/gdm/gdm.conf
/etc/X11/xdm/Xaccess
/etc/aliases
/etc/cron.allow
/etc/cron.deny
/etc/at.allow
/etc/at.deny
/etc/cron.d/at.allow
/etc/cron.d/cron.allow
/etc/dfs/dfstab
/etc/exports
/etc/fstab
/etc/ftpaccess
/etc/ftphosts
/etc/ftpgroups
/etc/ftpconversions
/etc/group
/etc/host.conf
/etc/inetd.conf
/etc/inittab
/etc/lilo.conf
/etc/login.conf
/etc/login.defs
/etc/mnttab
/etc/motd
/etc/issue
/etc/mtab
/etc/nsswitch.conf
/etc/master.passwd
/etc/profile
/etc/redhat-release
/etc/resolv.conf
/etc/securetty
/etc/sysconfig/authconfig
/etc/sysctl.conf
/etc/syslog.conf
/etc/system
/etc/ttys
/etc/vfstab
/var/at/at.allow
/var/at/at.deny
/etc/shells
"

echo "[++] Copying files" >> $DEBUG_LOG
echo "[++] Copying files"
N="-n"
C="\c"

if [ "-n" == "`echo -n`" ]; then
     N=""
else
     C=""
fi

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . 2> /dev/null

         if [ $? -ne 0 ]; then
            ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
         fi

         echo $N ".$C"
      else
         ls -la "$f" 1>> ./not-found.txt  2>> ./not-found.txt
      fi
done
echo

cp -fR /etc/security . 2>> ./not-found.txt
cp -r /etc/pam.d . 2>> ./not-found.txt
cp -r /etc/sysconfig . 2>> ./not-found.txt
cp /var/adm/cron/*.allow . 2>> ./not-found.txt
cp /etc/dt/config/Xaccess Xaccess-etc 2>> ./not-found.txt
cp /etc/ftp* . 2>> ./not-found.txt
cp /etc/hosts* . 2>> ./not-found.txt
cp /etc/passwd . 2>> ./not-found.txt
cp /etc/*shrc . 2>> ./not-found.txt
cp -Rpf /etc/rc* . 2>> ./not-found.txt
cp /usr/dt/config/Xaccess Xaccess-usr 2>> ./not-found.txt
cp /var/cron/allow cron.allow 2>> ./not-found.txt

get_shadow "$COPY_HASHES"

lastlog > ./lastlog.txt  2>> ./not-found.txt

mkdir root
cp ~root/.*rc ./root 2>> ./not-found.txt
cp ~root/.bash_profile ./bash_profile-root 2>> ./not-found.txt
cp ~root/.bash_profile bash_profile-root 2>> ./not-found.txt
cp ~root/.bashrc ./bashrc-root 2>> ./not-found.txt
cp ~root/.bashrc bashrc-root 2>> ./not-found.txt
cp ~root/.cshrc ./cshrc-root 2>> ./not-found.txt
cp ~root/.cshrc cshrc-root 2>> ./not-found.txt
cp ~root/.login ./root 2>> ./not-found.txt
cp ~root/.login login-root 2>> ./not-found.txt
cp ~root/.profile ./profile-root 2>> ./not-found.txt
cp ~root/.profile ./root 2>> ./not-found.txt
cp ~root/.profile profile-root 2>> ./not-found.txt
cp ~root/csh.cshrc csh.cshrc-root 2>> ./not-found.txt
cp ~root/csh.login csh.login-root 2>> ./not-found.txt


echo "[++] Searching Permissions" >> $DEBUG_LOG
echo "[++] Searching Permissions"
ls -l /bin/su > su.txt  2>> ./not-found.txt
ls -l /etc > etc.txt  2>> ./not-found.txt
ls -l /etc 1> etc_ls.txt 2>> ./not-found.txt
ls -l /etc/exports > exports_listagem.txt  2>> ./not-found.txt
ls -l /etc/inetd.conf > inetd_perm.txt  2>> ./not-found.txt
ls -l /etc/lilo.conf > lilo_perm.txt  2>> ./not-found.txt
ls -l /var/adm > log.txt  2>> ./not-found.txt
ls -l /var/adm/loginlog > loginlog_listagem.txt  2>> ./not-found.txt
collect_gcc_perms
[ -n "`which su`" ] && ls -lL `which su` 1> su_perm.txt 2>> ./not-found.txt

home_dir_list=`get_home_directories "$SORT"`
printf "`ls -ld $home_dir_list`" >> home_listagem.txt  2>> ./not-found.txt

ls -la /var/adm > varadm_listagem.txt  2>> ./not-found.txt
ls -la /var/cron/tabs > crontabs_listagem.txt  2>> ./not-found.txt
ls -la /var/log > varlog_listagem.txt  2>> ./not-found.txt
ls -lad /etc/cron.d > cron.d_perm.txt  2>> ./not-found.txt
ls -lad /etc/xinetd.d /etc/xinetd.conf > xinetd_perm.txt  2>> ./not-found.txt
ls -ladL /tmp /var/tmp > tmps_listagem.txt  2>> ./not-found.txt
ls -ld /etc/notrouter > notrouter_listagem.txt  2>> ./not-found.txt
ls -ld /tmp > tmp.txt  2>> ./not-found.txt
ls -ld /var/tmp >> tmp.txt  2>> ./not-found.txt

find /var/log -perm +0066 -ls |grep -v lrwxrwxrwx > varlog_find.txt
find /etc -perm -0002 \( -type f -o -type d \) -exec ls -ld {} \; > etc_find.txt

echo "[++] Getting system information" >> $DEBUG_LOG
echo "[++] Getting system information"

cat /proc/sys/net/ipv4/conf/all/accept_source_route > accept_source_route.txt 2>> ./not-found.txt
cat /proc/sys/net/ipv4/conf/all/forwarding > forwarding.txt 2>> ./not-found.txt
cat /proc/sys/net/ipv4/conf/all/log_martians > log_martians.txt 2>> ./not-found.txt
cat /proc/sys/net/ipv4/conf/all/rp_filter > rp_filter.txt 2>> ./not-found.txt
cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts > icmp_echo_ignore_broadcasts.txt 2>> ./not-found.txt
cat /proc/sys/net/ipv4/tcp_syncookies > tcp_syncookies.txt 2>> ./not-found.txt

if [ -n "$CHKCONFIG" ]; then

  chkconfig --list > chkconfig.txt 2>> ./not-found.txt

else

  chkconfig_list > chkconfig.txt 2>> ./not-found.txt

fi

mkdir ./default
cat /etc/default/inet > ./default/inet 2>> ./not-found.txt
cat /etc/default/authsh > ./default/authsh 2>> ./not-found.txt
cat /etc/default/passwd > ./default/passwd 2>> ./not-found.txt
cat /etc/default/su > ./default/su 2>> ./not-found.txt
cat /etc/default/cron > ./default/cron 2>> ./not-found.txt
cat /etc/default/login > ./default/login 2>> ./not-found.txt
cat /etc/default/idleout > ./default/idleout 2>> ./not-found.txt


df -k > df.txt 2>> ./not-found.txt
dmesg > dmesg.txt 2>> ./not-found.txt
domainname > domainname.txt 2>> ./not-found.txt
hostname > hostname.txt 2>> ./not-found.txt
id > id.txt 2>> ./not-found.txt
ifconfig -a > ifconfig-a.txt 2>> ./not-found.txt
instfix -i > patch.txt 2>> ./not-found.txt
lsattr /var/log/messages > messages-lsattr.txt 2>> ./not-found.txt
lsattr /var/log/secure > secure-lsattr.txt 2>> ./not-found.txt
lsmod > lsmod.txt 2>> ./not-found.txt
lssrc -a > lssrc.txt 2>> ./not-found.txt

ndd -get /dev/ip ip_forward_directed_broadcasts > directed_broadcasts_ndd.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_forward_src_routed > src_routed_ndd.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_forwarding > ip_forwarding_ndd.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_ignore_redirect > ignore_redirect_ndd.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_echo_broadcast > echo_broadcast_ndd.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_timestamp > respond_to_timestamp_ndd.txt 2>> ./not-found.txt
ndd -get /dev/ip ip_respond_to_timestamp_broadcast > timestamp_broadcast_ndd.txt 2>> ./not-found.txt
ndd -get /dev/tcp tcp_sack_permitted > sack_permitted_ndd.txt 2>> ./not-found.txt

if [ -n "$NETSTAT" ]; then

  netstat -na > netstat-na.txt 2>> ./not-found.txt
  netstat -nr > netstat-nr.txt 2>> ./not-found.txt

else

  cp --parents /proc/net/unix /proc/net/tcp /proc/net/tcp6 /proc/net/route /proc/net/udp /proc/net/udp6 . 2>> ./not-found.txt

fi

nisdomainname > nisdomainname.txt 2>> ./not-found.txt
no -a > netsec.txt 2>> ./not-found.txt
pkg_info > pkg_info.txt 2>> ./not-found.txt
ps -ef > ps-ef.txt 2>> ./not-found.txt
ps auxww > ps-auxww.txt 2>> ./not-found.txt

rpm -qa > rpm-q-a.txt 2>> ./not-found.txt &

kill_rpm "360"

set > set.txt 2>> ./not-found.txt

showrev -p > showrev.txt  2>> ./not-found.txt
showrev -p  2>> ./not-found.txt | cut -f2 -d  ' ' > patches.txt

if [ -n "$SYSCTL" ]; then

  sysctl -a > sysctl-a.txt 2>> ./not-found.txt

else

  gather_kernel_params  

fi

uname -a > uname.txt 2>> ./not-found.txt
w > w.txt 2>> ./not-found.txt
ypdomainname > ypdomainname.txt 2>> ./not-found.txt
hostid > hostid.txt 2>> ./not-found.txt

echo "[++] Collecting SUIDs" >> $DEBUG_LOG
echo "[++] Collecting SUIDs"
find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -perm +6000 -ls >> sid.txt
find /usr/ccs/bin /usr/ucb /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \( -perm -4000 -o -perm -2000 \) -ls >> sid.txt

for h in $home_dir_list; do
     [ -s $h/.netrc ] && {
          ls -ld $h/.netrc >> netrc.txt
     }
     [ -s $h/.rhosts ] && {
          ls -ld $h/.rhosts >> rhosts.txt
          cat $h/.rhosts >> rhosts.txt
     }
done

  ;;
esac
   echo "[++] Generating Host ID" >> $DEBUG_LOG
   echo "[++] Generating Host ID"
if [ "$OSVER" != "VMkernel" ]; then 
   echo "[++] Collecting Services" >> $DEBUG_LOG
   echo "[++] Collecting Services"

PSANT=$PS2
PS2="# "

SORT=`which sort`
NETSTAT=`which netstat`

CP_FILES="/etc/pf.conf
/etc/nat.conf
/etc/ipf.rules
/etc/nat.rules
/etc/ipnat.rules
/etc/sendmail*
/etc/aliases
/etc/mail/sendmail*
/etc/xinetd.conf
"

N="-n"
C="\c"

echo "[+++] Copying files" >> $DEBUG_LOG
echo "[+++] Copying files"

if [ "`echo -n`" = "-n" ]; then
     N=""
else
     C=""
fi

for f in $CP_FILES; do
      if [ -f "$f" ]; then
         cp "$f" . > /dev/null  2>> ./not-found.txt

         if [ $? -eq 1 ]; then
               ls -la "$f" >> ./not-found.txt  2>> ./not-found.txt
         fi

         echo $N ".$C"
      else
         ls -la "$f" >> ./not-found.txt  2>> ./not-found.txt
      fi
done

oldIFS=$IFS
IFS='
'

CP_R_FILES="/etc/mail:.
/var/www/conf:apache-varwww
/var/qmail/control:qmail-control
/var/qmail/aliases:qmail-aliases
/var/security/backup:.
/etc/xinetd.d:.
"

for f in $CP_R_FILES; do
      src=`echo $f | sed "s/^\([^ ]*\):.*/\1/"`
      dst=`echo $f | sed "s/^[^ ]*:\(.*\)/\1/"`

      if [ -d "$src" ]; then
         cp -r "$src" "$dst" 2> /dev/null

         if [ $? -eq 1 ]; then
              ls -la "$src" 1>> ./not-found.txt  2>> ./not-found.txt
         fi
         echo $N ".$C"
      else
         ls -la "$src" 1>> ./not-found.txt  2>> ./not-found.txt
      fi
done

IFS=$oldIFS

cp /var/qmail/rc qmail-rc 2>> ./not-found.txt
cp /etc/proftpd.conf proftpd-etc 2>> ./not-found.txt
cp /etc/pure-ftpd.conf pure-ftpd.conf 2>> ./not-found.txt
cp /usr/local/etc/proftpd.conf proftpd-usrlocal 2>> ./not-found.txt

echo

ls -lLd /var/spool/mqueue > mqueue-ls 2>> ./not-found.txt
ls -lL /etc/mail > ls-lL-etcmail 2>> ./not-found.txt


echo "[+++] Searching Samba" >> $DEBUG_LOG
echo "[+++] Searching Samba"

smbInstances=`eval $PROCESSES | grep "^[^ ]*smbd "`

if [ -n "$SORT" ]; then

  smbInstances=`printf "$smbInstances" | sort -u`

else

  smbInstances=`remove_dup "$smbInstances"`

fi

if [ -n "$smbInstances" ]; then
    echo "[++++] Found Samba Daemon on process list" >> $DEBUG_LOG;
    echo "[++++] Found Samba Daemon on process list";
SMB_FILES="/etc/samba/smb.conf
/usr/local/etc/smb.conf
/usr/local/samba/etc/smb.conf
/opt/samba/etc/smb.conf
/usr/samba/lib/smb.conf
/etc/smb.conf
/etc/opt/samba/smb.conf
/usr/local/samba/lib/smb.conf"

for file in $SMB_FILES ; do
    if [ -f "$file" ] ; then
       cp "$file" . 2>> ./not-found.txt
       break
    fi
done

    instance=`echo $smbInstances | cut -d" " -f1`
    [ "`echo $instance | cut -c1 `" != "/" ] || [ ! -x "$instance" ] && instance="smbd"
    $instance -V > samba-v.txt 2>> ./not-found.txt
fi

echo "[+++] Getting services information" >> $DEBUG_LOG
echo "[+++] Getting services information"

mount > mount.txt   2>> ./not-found.txt
httpd -V >> httpd-v.txt  2>> ./not-found.txt
wu.ftpd -V >> wu-ftpd-v.txt  2>> ./not-found.txt
sshd -T >> sshd-t.txt  2>> ./sshd-t.txt
sshd -V >> sshd-v.txt  2>> ./sshd-v.txt
/usr/local/sbin/sshd -V 2>> sshd-v-usrlocal.txt  2>> ./not-found.txt
squid -v >> squid-v.txt  2>> ./not-found.txt
/usr/local/sbin/squid -v >> squid-v-usrlocal.txt  2>> ./not-found.txt

if [ -n "$NETSTAT" ]; then

  netstat -ni > netstat-ni.txt  2>> ./not-found.txt
  netstat -nr 1> netstat-nr.txt 2>> ./not-found.txt

else

  cp --parents /proc/net/dev /proc/net/route . 2>> ./not-found.txt

fi

/usr/bin/openssl version > openssl-version.txt  2>> ./not-found.txt
/usr/local/bin/openssl version > openssl-local.txt  2>> ./not-found.txt

mkdir database

PS2=$PSANT
IFS=$oldIFS


sendmail_files="`find /etc -xdev -name sendmail.cf`"
for file in $sendmail_files; do
  
  [ -f "$file" ] && {

    help_file="`grep -v '^[[:blank:]]*#' $file | grep '[[:blank:]]*O[[:blank:]]\{1,\}HelpFile' | awk -F= '{ print $2 }'`"
    
    ls_file_name="`echo "$help_file" | sed 's/[[:blank:]]//g' | sed 's/[/]/_/g'`"

    if [ -f "$help_file" ]; then  
      ls -al ${help_file} > ./ls-${ls_file_name}.txt
    fi
  }

done


#############
# Looking for php configuration and binary
######################################################
php_bin_paths="
/usr/bin/php
/bin/php
/usr/local/bin/php
/opt/local/bin/php
"

php_bin=`which php 2>/dev/null | grep -v 'no php'`
if [ -n "$php_bin" ]; then

        $php_bin -v > ./php-version.txt 2>>./not-found.txt
        php_ini_file=`$php_bin -r "phpinfo();" 2>>./not-found.txt | awk ' $NF ~ /php\.ini/ { print $NF } '`
	php_additional_dir=`$php_bin -r "phpinfo();" 2>>./not-found.txt | grep -i "for additional \.ini files" | awk '{ print $NF }'`

        [ -f "$php_ini_file" ] && cp $php_ini_file ./php.ini 2>>./not-found.txt
        [ -f "$php_ini_file/php.ini" ] && cp "$php_ini_file/php.ini" ./php.ini 2>>./not-found.txt
	[ -d "$php_additional_dir" ] && cp -r "$php_additional_dir" ./php.d 2>>./not-found.txt
else

        for php_bin in ${php_bin_paths}; do

                [ -x "$php_bin" ] && {

                        $php_bin -v > ./php-version.txt 2>>./not-found.txt
                        php_ini_file=`$php_bin -r "phpinfo();" 2>>./not-found.txt | egrep "php\.ini" | awk '{ print $NF }'`
			php_additional_dir=`$php_bin -r "phpinfo();" 2>>./not-found.txt | grep -i "for additional \.ini files" | awk '{ print $NF }'`

                        [ -f "$php_ini_file" ] && cp $php_ini_file ./php.ini 2>>./not-found.txt
                        [ -f "$php_ini_file/php.ini" ] && cp "$php_ini_file/php.ini" ./php.ini 2>>./not-found.txt
			[ -d "$php_additional_dir" ] && cp -r "$php_additional_dir" ./php.d 2>>./not-found.txt
                }
                break
        done
fi


######################################################
# Looking for MySQL configuration 
######################################################
gather_mysql() {

        echo "[+++] Searching MySQL on process list" >> $DEBUG_LOG
        echo "[+++] Searching MySQL on process list"

        mysqld_is_running=`ps -ef | egrep "mysqld" | egrep -v "grep"`
        [ -z "$mysqld_is_running" ] && return

        MYSQL_LOCATIONS="/etc/
/etc/mysql/
/usr/etc/
/usr/"

        for mycnf in ${MYSQL_LOCATIONS}; do

                if [ -f "$mycnf/my.cnf" ]; then

                        mkdir -p mysql
                        cp "$mycnf/my.cnf" mysql/
                        ps -ef | egrep "mysqld" | egrep -v "grep" > mysql/proc.txt
                        mysql_datadir=`cat mysql/proc.txt | egrep -o "datadir=[a-zA-Z0-9\/\-\_]+" | awk -F'=' '{ print $2 }' | sort -u`
                        [ -n "$mysql_datadir" -a -d "$mysql_datadir" ] && ls -ld "$mysql_datadir/"* > mysql/datadir-perm.txt
			mysqld_bin=`cat mysql/proc.txt | awk ' $8 ~ /mysqld/ { print $8 }'`
			[ -n "$mysqld_bin" -a -f "$mysqld_bin" ] && eval "$mysqld_bin" -V 2>/dev/null > mysql/mysqld-V.txt
			echo "$mycnf/my.cnf" > mysql/conf-path.txt
                        break
                fi
        done
}

gather_mysql
######################################################

echo "[+++] Searching Oracle on process list" >> $DEBUG_LOG
echo "[+++] Searching Oracle on process list"

ORADIR='ora_col'
ORAPROC=`eval $PROCESSES | grep ora_pmon_ | grep -v grep`

if [ -n "$ORAPROC" ]; then

RESTON_INSTANCES="HYPDEV /u01/app/orahypdb/product/9.2/
TRDEVDB /u01/app/oratrdb/product/92/
CGDBPROD /u05/app/oracgdb/product/9.2/
HYPPROD /u01/app/orahyp/product/9.2/
CTDBPROD /u01/app/oractdb/product/9.2/
PROD /p02/oracle/proddb/8.1.7/
CT04DB /u01/app/oract04/product/9.2/
APPS_PROD /p02/oracle/prodora/8.0.6/
TRTRNDB /u02/app/oratrndb/product/92/
TRTEMPDB /u01/app/oratrdb/product/92/
TEST /t02/oracle/testdb/8.1.7/"

ORA_PERMS='j2ee/OC4J_Demos/applications/ojspdemos
Apache/Jsdk/examples
Apache/fastcgi/examples
Apache/BC4J/samples
Apache/Jserv/servlets/Hello*
Apache/Jserv/servlets/IsIt*
panama/WebIntegration/Server/samples
panama/WebIntegration/Server/HmUtil/samples
panama/sample
ldap/demo
soap/samples'

    mkdir $ORADIR

    OLDD=`pwd`
    cd $ORADIR

    if [ "`uname -s`" = "SunOS" ]; then
       AWK=`which nawk 2>/dev/null`
       PWDX=`which pwdx 2> /dev/null`
    else
       AWK=`which awk 2>/dev/null`
       PWDX=""
    fi

    echo "[++++] Collecting Oracle DB instances" >> $DEBUG_LOG
    echo "[++++] Collecting Oracle DB instances"
    oraInstances=`ps -ef | sed -n '/sed/d; s/^.*ora_pmon_//p'`

    for instance in $oraInstances; do
        mkdir "$instance"

        userInstance=`ps -ef | sed -n "/sed/d; /ora_pmon_$instance/s/^ *//p" | cut -d" " -f1`
        groupInstance=`groups $userInstance | cut -d" " -f1`

        echo "_STANZA=\"$instance\"" >> "$instance/env"
        echo "_USER=\"$userInstance\"" >> "$instance/env"
        echo "_GROUP=\"$groupInstance\"" >> "$instance/env"
    done

    ls */env > /dev/null && {

        echo "[++++] Found Oracle DB instances:" >> $DEBUG_LOG
        echo "[++++] Found Oracle DB instances:"
        ls */env
        echo

        ps -ef | grep "/tnslsnr" | grep -v grep > tnslsnr.txt
        ps -ef | grep "/tnslsnr" | grep -v grep | awk -F' ' '{print $10}' > tnslsnr_awk.txt
        ps -ef | grep "/tnslsnr" | grep -v grep | cut -d: -f2 > tnslsnr_reduz.txt


        ps -ef | grep "httpd" | grep -v grep > httpd.txt

        DEFAULT_LOCATIONS="/var/opt/oracle /etc"
        LOG="sql.log"
        HOST=`hostname`

        unset ORAFILE
        unset ORATAB
        echo "Collecting ORATAB file configuration.."
                
        for local in $DEFAULT_LOCATIONS; do
            [ -s "$local/oratab" ] && {
                ORAFILE="$local/oratab"
                ORATAB="$local"

                echo "[+++++] Found ORATAB file on $local. Using it for search instances" >> $DEBUG_LOG
                echo "[+++++] Found ORATAB file on $local. Using it for search instances"
                break
            }
        done

        if [ -z "$ORAFILE" ]; then
            echo "[+++++] ORATAB File Not found by Script for instance: $stanza" >> $LOG
            echo "[+++++] ORATAB File Not found by Script for instance: $stanza" >> $DEBUG_LOG
            echo "[++++] Exiting.." >> $DEBUG_LOG
            echo "[+++++] ORATAB File Not found by Script for instance: $stanza" 
            echo "[++++] Exiting.."
        else
            cp -f "$ORAFILE" .
            cp -f "$ORATAB/oraInst.loc" . 2>> ./not-found.txt

            for stanza in `ls */env`; do

               unset HOME
               echo "Using instance config: $stanza"
               eval `cat $stanza`

               echo "ORATAB=\"$ORATAB\"" >> $stanza

               if [ -x "$PWDX" ]; then
                    pid=`ps -ef | sed -n "/ora_pmon_${_STANZA}$/s/^ *[^ ]* *\([0-9]*\).*$/\1/p"`
                    HOME=`$PWDX $pid | sed 's/^[^\/]*\(.*\)\/dbs$/\1/'`
               fi

               if [ ! -d "$HOME" ]; then
                   HOME=`echo "$RESTON_INSTANCES" | sed -n "s/^${_STANZA} \(.*\)$/\1/p"`
               fi

               if [ ! -d "$HOME" ]; then
                     HOME=`$AWK -F: "/^${_STANZA}:/ {print \\$2; exit}" "$ORAFILE"`
               fi

               if [ ! -d "$HOME" ]; then
                    HOME=`$AWK -F: "/^${_STANZA}:/ {print \\$2; exit}" "$ORAFILE"`
               fi

               if [ ! -d "$HOME" ]; then
                   HOME=`$AWK -F: ' $1 == "*" { print $2; exit}' "$ORAFILE"`

                   if [ ! -d "$HOME" ]; then
                       HOME=`$AWK -F: "/^${_USER}:/ {print \\$6; exit}" /etc/passwd`
                       if [ "$HOME" = "" ]; then
                           HOME=`ypmatch oracle passwd.byname 2>/dev/null | awk -F: '/^oracle:/ {print $6; exit}'`
                       fi
                   fi
               fi

               echo "ORACLE_HOME=\"$HOME\"" >> $stanza
               echo "ORACLE_SID=\"$_STANZA\"" >> $stanza
               echo "TWO_TASK=\"$_STANZA\"" >> $stanza
               echo "PATH=\"$HOME/bin:$PATH\"" >> $stanza

               eval `cat $stanza`
               export ORACLE_HOME ORACLE_SID PATH HOME

               echo "[+++++] Collecting permissions" >> $DEBUG_LOG
               echo "[+++++] Collecting permissions"

               for dir in $ORA_PERMS; do
                   echo "Permissions in directory: $dir" >> "${ORACLE_SID}/examples.txt"
                   ls -lL "$HOME/$dir" >> "${ORACLE_SID}/examples.txt" 2> ./not-found.txt
               done

               ls -lL "$HOME/" > "${ORACLE_SID}/home_perms.txt"
               ls -lL "$HOME/bin/" > "${ORACLE_SID}/bin_perms.txt"
               ls -lL "$HOME/network/admin/" > "${ORACLE_SID}/netadmin_perms.txt"

               echo "Hostname: `hostname`" >> "${ORACLE_SID}/netadmin_perms.txt"
               echo "ORACLE_HOME: $HOME" >> "${ORACLE_SID}/netadmin_perms.txt"

               echo "Hostname: `hostname`" >> "${ORACLE_SID}/home_perms.txt"
               echo "ORACLE_HOME: $HOME" >> "${ORACLE_SID}/home_perms.txt"

               echo "Hostname: `hostname`" >> "${ORACLE_SID}/bin_perms.txt"
               echo "ORACLE_HOME: $HOME" >> "${ORACLE_SID}/bin_perms.txt"

               echo "[+++++] Copying listener" >> $DEBUG_LOG
               echo "[+++++] Copying listener"
               cp "$HOME/network/admin/listener.ora" "${ORACLE_SID}/listener.ora" 2> ./not-found.txt
               ls -la "$HOME/network/admin/" >> "${ORACLE_SID}/listener-ls.txt" 2> ./not-found.txt
	       cp "$HOME/network/admin/sqlnet.ora" "${ORACLE_SID}/sqlnet.ora" 2> ./not-found.txt
               cp "$HOME/dbs/init.ora" "${ORACLE_SID}/init.ora" 2> ./not-found.txt
	       ls -la "$HOME/network/agent/" >> "${ORACLE_SID}/snmp-ls.txt"   2> ./not-found.txt
	       cp "$HOME/network/agent/snmp*ora" "${ORACLE_SID}/" 2> ./not-found.txt
               ls -ld $HOME/* > oracle_home_perms.txt 2> ./not-found.txt


               [ -f "$ORATAB/oraInst.loc" ] && {
                   INVENTORY=`awk -F= ' /inventory_loc/ { print $2; exit } ' "$ORATAB/oraInst.loc"`
                   
                   if [ -f "$INVENTORY/ContentsXML/comps.xml" ]; then
                         compsFile="$INVENTORY/ContentsXML/comps.xml"
                   fi
               }
               
               if [ -f "$HOME/oraInventory/ContentsXML/comps.xml" ]; then
                    compsFile="$HOME/oraInventory/ContentsXML/comps.xml"
               fi
               if [ -f "$HOME/Inventory/ContentsXML/comps.xml" ]; then
                    compsFile="$HOME/Inventory/ContentsXML/comps.xml"
               fi
               if [ -f "$HOME/inventory/ContentsXML/comps.xml" ]; then
                    compsFile="$HOME/inventory/ContentsXML/comps.xml"
               fi

               if [ -n "$compsFile" ]; then
                    $AWK ' BEGIN { patch = 0; oneoff = 0; comp = 0 }
                           $1 == "<PATCHSET" { patch  = 1 } 
                           $1 == "<ONEOFF"   { oneoff = 1 }
                           $1 == "<COMP" && comp == 0  { comp   = 1 } 
                           patch == 1 || oneoff == 1 || comp == 1 { print } 
                           $1 == "</ONEOFF>"   { oneoff = 0 }
                           $1 == "</PATCHSET>" { patch  = 0 } 
                           $0 ~ /<\/EXT_NAME>/ { comp   = 2 } ' "$compsFile" > "${ORACLE_SID}/inventory_comps.xml" 2> ./not-found.txt
               fi     

               cp "$HOME/Apache/modpls/cfg/wdbsrv.app" "${ORACLE_SID}/wdbsrv.app" 2> ./not-found.txt
               cp "$HOME/Apache/modplsql/conf/dads.conf" "${ORACLE_SID}/dads.conf" 2> ./not-found.txt
               cp "$HOME/sysman/emd/targets.xml" "${ORACLE_SID}/targets.xml" 2> ./not-found.txt

               echo "Hostname: `hostname`" >> "${ORACLE_SID}/listener.ora"
               echo "ORACLE_HOME: $HOME" >> "${ORACLE_SID}/listener.ora"
               echo "------------------------------------------" >> "${ORACLE_SID}/listener.ora"
               $HOME/bin/lsnrctl version >> "${ORACLE_SID}/listener.ora"

               echo "[+++++] Executing database collection" >> $DEBUG_LOG
               echo "[+++++] Executing database collection"
               eval `cat $stanza`
               export ORACLE_HOME ORACLE_SID PATH
               echo "----------------- Instance $ORACLE_SID -----------------" >> $LOG

               echo "[++++] Done for instance: $ORACLE_SID" >> $DEBUG_LOG
               echo "[++++] Done for instance: $ORACLE_SID"
          done

          echo "[++++] Finished Oracle DB collection" >> $DEBUG_LOG
          echo "[++++] Finished Oracle DB collection"

       fi
    }

        cd "$OLDD"

        oracle_asm_dir="/var/security/.oracle_asm/"
        [ -d "$oracle_asm_dir" ] && {

                test_files_inside=`ls -1 "$oracle_asm_dir"/ 2>/dev/null | egrep -i "\.txt$"`
                [ -n "$test_files_inside" ] && {

                        mkdir -p "$ORADIR/extra_asm_instances/"
                        cp "$oracle_asm_dir"/*.txt "$ORADIR/extra_asm_instances/" 2>/dev/null
                }
        }

else
        echo "[++++] Oracle not found." >> $DEBUG_LOG
        echo "[++++] Oracle not found."
fi

if [ $IGNORE_APACHE -ne 1 ]; then

    echo "[+++] Searching Apache httpd" >> $DEBUG_LOG
    echo "[+++] Searching Apache httpd"
#!/bin/sh

HTTPD_DEFAULT_DIRS="
/etc/httpd
/etc/apache
/usr/local/apache
/usr/local/apach2
/opt/apache
/webtools/apache/
"

SORT=`which sort`

if [ -z "$SORT" ]; then

  httpInstances=`eval $PROCESSES`
  httpInstances=`remove_dup "$httpInstances" | grep -E "^/[^ ]*/(httpd|apache)" | grep -v "rotatelogs"`

else

  httpInstances=`eval $PROCESSES | $SORT -u | grep -E "^/[^ ]*/(httpd|apache)" | grep -v "rotatelogs"`

fi

DIRCOL=`pwd`
cont=0
oldIFS=$IFS
IFS='
'

for instance in $httpInstances; do
    unset configFile
    unset httpDir

    apache_error=0
    cont=`expr $cont + 1`
    cmd_apache=`echo $instance | cut -d" " -f1`
    configFile=`echo $instance | awk ' {

       for(i = 2; i <= NF; i++)
            if($i == "-f" && i < NF) {
                print $(i + 1)
                break
            }
    }'`

    serverRoot=`echo $instance | awk ' {

        for(i = 2; i <= NF; i++)
            if($i == "-d" && i < NF) {
                print $(i + 1)
                break
            }
    }'`

    version=`$cmd_apache -V`
    if [ "$?" != "0" ]; then
        cmd_apache="`dirname $cmd_apache`/apachectl"
        echo "[++++] Problems running Apache Server instance at $cmd_apache, trying apachectl" >> $DEBUG_LOG
        echo "[++++] Problems running Apache Server instance at $cmd_apache, trying apachectl"

        [ ! -f "$cmd_apache" ] && {
         echo "[++++] $cmd_apache not found, skipping this instance." >> $DEBUG_LOG
         echo "[++++] $cmd_apache not found, skipping this instance." 
         continue
        }
    fi

    if [ -z "$serverRoot" ] || [ ! -d "$serverRoot" ]; then
        if [ -n "$serverRoot" ]; then
           echo "[++++] Configuration Directory $serverRoot not found" >> $DEBUG_LOG
           echo "[+++++] Getting compiled Configuration Directory" >> $DEBUG_LOG
           echo "[++++] Configuration Directory $serverRoot not found"
           echo "[+++++] Getting compiled Configuration Directory"
        fi
        serverRoot=`$cmd_apache -V | sed -n 's/"//g; /HTTPD_ROOT/s/^.*HTTPD_ROOT=\(.*\)/\1/p'`
    fi

    if [ -z "$configFile" ] || [ ! -f "$configFile" ]; then
        if [ -n "$configFile" ]; then
            echo "[++++] Configuration file $configFile not found" >> $DEBUG_LOG
            echo "[++++] Configuration file $configFile not found"
        fi
        configFile=`$cmd_apache -V | sed -n 's/"//g; /SERVER_CONFIG_FILE/s/^.*SERVER_CONFIG_FILE=\(.*\)/\1/p'`
    fi

    if [ "`echo $configFile | cut -c1 `" != "/" ]; then
        configFile="$serverRoot/$configFile"
    fi

    configDir=`echo $configFile | sed -n "s;^\(/[^ ]*\)/.*$;\1;p"`
    httpDir="http"`echo $configDir | tr "/" "-"`

    if [ -z "$configDir" ] || [ ! -d "$configDir" ]; then
         echo "[++++] Configuration Directory $configDir not found." >> $DEBUG_LOG
         echo "[+++++] Assuming that the binary directory is the configuration directory" >> $DEBUG_LOG
         echo "[++++] Configuration Directory $configDir not found."
         echo "[+++++] Assuming that the binary directory is the configuration directory"
         configDir="`echo $cmd_apache | sed 's/\/bin\/httpds\?$//g; s/\/bin\/apache2\?$//g'`"
         httpDir="http"`echo $configDir | tr "/" "-"`
    fi

    if [ -z "$configDir" ] || [ ! -d "$configDir" ]; then
         configDir="$configDir not found."
    fi

    if [ -z "$configFile" ] || [ ! -f "$configFile" ]; then
        configFile="$configFile not found."
        apache_error=1
    fi
    
    echo "[++++] Found Apache Server instance at $cmd_apache" >> $DEBUG_LOG
    echo "[++++] Found Apache Server instance at $cmd_apache"

    if [ "$apache_error" = "1" ]; then
        echo "[+++++] Configuration Directory not found." >> $DEBUG_LOG
        echo "[+++++] Searching default configurations..." >> $DEBUG_LOG
        echo "[+++++] Configuration Directory not found."
        echo "[+++++] Searching default configurations..."

        for apache_dir in $HTTPD_DEFAULT_DIRS; do
            if [ -d "$apache_dir" -a -f "${apache_dir}/conf/httpd.conf" -o -f "${apache_dir}/httpd.conf" ]; then
                echo "[++++++] Found Directory at $apache_dir" >> $DEBUG_LOG
                echo "[++++++] Copying Files" >> $DEBUG_LOG
                echo "[++++++] Found Directory at $apache_dir"
                echo "[++++++] Copying Files"

                if [ -f "${apache_dir}/httpd.conf" ]; then
                     configFile="${apache_dir}/httpd.conf"
                else
                     configFile="${apache_dir}/conf/httpd.conf"
                fi

                serverRoot="$apache_dir"

                httpDir="httpd"`echo "$apache_dir" | tr "/" "-"`
                httpDir="${httpDir}-default"
                mkdir "$httpDir"

                cd "$serverRoot"

                $cmd_apache -V > "${DIRCOL}/${httpDir}/httpd-version.txt"
                $cmd_apache -l > "${DIRCOL}/${httpDir}/httpd-compiled-modules.txt"

                echo "ServerRoot=\"$serverRoot\"" > "${DIRCOL}/${httpDir}/config.txt"
                echo "ConfigFile=\"$configFile\"" >> "${DIRCOL}/${httpDir}/config.txt"


                CGIDIR=`sed    -n 's/"//g; /^ *ScriptAlias /s/^ *ScriptAlias *[^ ]* *\(.*\)/\1/p' $configFile`
                CUSTOMLOG=`sed -n 's/"//g; /^ *CustomLog /s/^ *CustomLog *//p' $configFile`
                ERRORLOG=`sed  -n 's/"//g; /^ *ErrorLog /s/^ *ErrorLog *//p' $configFile`           
                DOCUMENTROOT=`sed -n "s/^ *DocumentRoot *\(.*\)/\1/p" $configFile`
                INCLUDES=`sed -n "s/^ *Include *\(.*\)/\1/p" $configFile`

                cp -R "$configFile" "${DIRCOL}/$httpDir/"
                echo "$configFile" >> "${DIRCOL}/$httpDir/configFile.txt"
 
                touch "$DIRCOL/$httpDir/httplogs_listagem.txt"

                IFS=$oldIFS

                for i in $CUSTOMLOG; do
                    ls -l "$i" >> "$DIRCOL/$httpDir/httplogs_listagem.txt";
                done

                for i in $ERRORLOG; do
                    ls -l "$i" >> "$DIRCOL/$httpDir/httplogs_listagem.txt";
                done

                if [ -n "$INCLUDES" ]; then
                    mkdir "$DIRCOL/$httpDir/includes"

                    for i in $INCLUDES; do
                          cp "$i" "$DIRCOL/$httpDir/includes/"
                    done
               fi

                for i in $CGIDIR; do
                    cgiDir=$i
                    [ "`echo $i | cut -c1 `" = "\"" ] && cgiDir=`echo $i | sed "s/^\"\(.*\)\"$/\1/"`
                    [ "`echo $i | cut -c1 `" = "/"  ] && cgiDir="$httpDir$i"

                    if [ -d "$cgiDir" ]; then
                        ls -la "$cgiDir" >> "$DIRCOL/$httpDir/cgi-bin_list.txt";
                    fi
                done

                IFS='
'
                [ "`echo $DOCUMENTROOT | cut -c1 `" = "\"" ] && DOCUMENTROOT=`echo $DOCUMENTROOT | sed "s/^\"\(.*\)\"$/\1/"`

                cp -r conf "$DIRCOL/$httpDir/"
                ls -la $DOCUMENTROOT > "$DIRCOL/$httpDir/documentroot_list.txt" 2>> /dev/null
                ls -la  fcgi-bin > "$DIRCOL/$httpDir/fcgi-bin_list.txt" 2>> /dev/null;
                ls -la  logs > "$DIRCOL/$httpDir/logs_list.txt" 2>> /dev/null;

                cd $DIRCOL
            fi
        done
    else
        echo "[+++++] Configuration Directory: $configDir" >> $DEBUG_LOG
        echo "[+++++] Configuration File: $configFile" >> $DEBUG_LOG
        echo "[+++++] Configuration Directory: $configDir"
        echo "[+++++] Configuration File: $configFile"

        httpDir="$httpDir$cont"

	##############
	#validating variables before to do anything
	###############################################
	if [ -n "$httpDir" ]; then

		if [ -z "$serverRoot" ]; then
			echo "[++++] Error trying to collect, skipping this instance." >> $DEBUG_LOG
			echo "[++++] Error trying to collect, skipping this instance."
			continue
		fi
	else
		echo "[++++] Error trying to collect, skipping this instance." >> $DEBUG_LOG
		echo "[++++] Error trying to collect, skipping this instance."
		continue
	fi
	###############################################

        mkdir -p "${DIRCOL}/${httpDir}"
        cd "$serverRoot"

        $cmd_apache -V > "${DIRCOL}/${httpDir}/httpd-version.txt"
        $cmd_apache -l > "${DIRCOL}/${httpDir}/httpd-compiled-modules.txt"


	##############
	#validating variables before to do anything
	###############################################
	[ -n "$configFile" ] && [ -f "$configFile" ] && {
        	
		##############
		#obtaining directory names from the main configuration file
		###############################################
		CGIDIR=`sed -n 's/"//g; /^ *ScriptAlias /s/^ *ScriptAlias *[^ ]* *\(.*\)/\1/p' $configFile`
        	CUSTOMLOG=`sed -n 's/"//g; /^ *CustomLog /s/^ *CustomLog *//p' $configFile`
        	ERRORLOG=`sed  -n 's/"//g; /^ *ErrorLog /s/^ *ErrorLog *//p' $configFile`

        	DOCUMENTROOT=`sed -n "s/^ *DocumentRoot *\(.*\)/\1/p" $configFile`
        	INCLUDES=`sed -n "s/^ *Include *\(.*\)/\1/p" $configFile`

	        cp "$configFile" "${DIRCOL}/$httpDir/"
        	echo "$configFile" >> "${DIRCOL}/$httpDir/configFile.txt"
		###############################################

	}
	###############################################

        touch "$DIRCOL/$httpDir/httplogs_listagem.txt"

        IFS=$oldIFS
        for i in $CUSTOMLOG; do
            ls -l "$i" >> "$DIRCOL/$httpDir/httplogs_listagem.txt" 2>> /dev/null;
        done

        for i in $ERRORLOG; do
            ls -l "$i" >> "$DIRCOL/$httpDir/httplogs_listagem.txt" 2>> /dev/null;
        done

        if [ -n "$INCLUDES" ]; then
            mkdir -p "$DIRCOL/$httpDir/includes"

            for i in $INCLUDES; do
                  cp "$i" "$DIRCOL/$httpDir/includes/"
            done
       fi

        for i in $CGIDIR; do
            cgiDir=$i

            [ "`echo $i | cut -c1 `" = "\"" ] && cgiDir=`echo $i | sed "s/^\"\(.*\)\"$/\1/"`
            [ "`echo $i | cut -c1 `" = "/"  ] && cgiDir="$httpDir$i"

            if [ -d "$cgiDir" ]; then
               ls -la "$cgiDir" >> "$DIRCOL/$httpDir/cgi-bin_list.txt" 2>> /dev/null;
            fi
        done

        IFS='
'
	documentroot_testing=`echo $DOCUMENTROOT | cut -c1`
	if [ -n "$documentroot_testing" ]; then
		if [ "$documentroot_testing" = "\"" ]; then
			DOCUMENTROOT=`echo $DOCUMENTROOT | sed "s/^\"\(.*\)\"$/\1/"`
		fi
	fi


        [ -d "$configDir/conf" ] && {

                mkdir -p "$DIRCOL/$httpDir/conf"
                cp -prH $configDir/conf/* "$DIRCOL/$httpDir/conf/" 2>>./not-found.txt || cp -pr $configDir/conf/* "$DIRCOL/$httpDir/conf/" 2>>./not-found.txt
        }


        [ -d "$configDir/conf.d" ] && {

                mkdir -p "$DIRCOL/$httpDir/conf.d"
                cp -rpH $configDir/conf.d/* "$DIRCOL/$httpDir/conf.d/" 2>>./not-found.txt || cp -rp $configDir/conf.d/* "$DIRCOL/$httpDir/conf.d/" 2>>./not-found.txt
        }


        [ -d "$configDir/sites-enabled" ] && {

                mkdir -p "$DIRCOL/$httpDir/sites-enabled"
                cp -rpH $configDir/sites-enabled/* "$DIRCOL/$httpDir/sites-enabled/" 2>>./not-found.txt || cp -rp $configDir/sites-enabled/* "$DIRCOL/$httpDir/sites-enabled/" 2>>./not-found.txt
        }

        ls -la $DOCUMENTROOT > "$DIRCOL/$httpDir/documentroot_list.txt" 2>> /dev/null
        ls -la  fcgi-bin > "$DIRCOL/$httpDir/fcgi-bin_list.txt" 2>> /dev/null;
        ls -la  logs > "$DIRCOL/$httpDir/logs_list.txt" 2>> /dev/null;

        cd $DIRCOL
    fi
done

IFS=$oldIFS

fi
# End Apache

    echo "[+++] Searching nginx" >> $DEBUG_LOG
    echo "[+++] Searching nginx"
#!/bin/sh

NGINX_DEFAULT_PATHS="/usr/sbin /usr/local/sbin /opt/sbin"
NGINX_DIR="nginx_gathering"
#Get Version
NGINX=`which nginx 2>>/dev/null| grep -v alias | grep -v 'no nginx' | awk '{print $1}'`
if [ -z "$NGINX" ]; then
        # NGINX not detected - check default paths
        for path in ${NGINX_DEFAULT_PATHS}; do
                if [ -f "${path}/nginx" ]; then
                        NGINX="${path}/nginx"
                        break
                fi
        done
fi
if [ -n "$NGINX" ]; then 
        echo "[++++] nginx found on $NGINX"
        
        echo -n "[++++]  Gathering nginx...."
        mkdir -p $NGINX_DIR/includes
        # Get version
        $NGINX -V >> $NGINX_DIR/nginx-v.txt 2>> $NGINX_DIR/nginx-v.txt

        #Get ps configuration
        ps x |grep nginx | grep master >> $NGINX_DIR/nginx-ps.txt
        
        # Get config file
	NGINX_CONFIG=`head -1 $NGINX_DIR/nginx-ps.txt | sed -n 's/^.*-c \([^\s]*\).*$/\1/p'`
        if [ ! -f "$NGINX_CONFIG" ]; then
 		NGINX_CONFIG=`head -1 $NGINX_DIR/nginx-ps.txt | sed -n 's/^.*-p \([^\s]*\).*$/\1/p'`
 		NGINX_CONFIG=`echo $NGINX_CONFIG/conf/nginx.conf`
 		if [ ! -f "$NGINX_CONFIG" ]; then
 			NGINX_CONFIG=`head -1 $NGINX_DIR/nginx-ps.txt | sed -n 's/^.*-p \([^\s]*\).*$/\1/p'`
 			NGINX_CONFIG=`echo $NGINX_CONFIG/nginx.conf`
 			if [ ! -f "$NGINX_CONFIG" ]; then
 				NGINX_CONFIG=`egrep -o -e '(conf-path=\S+)' $NGINX_DIR/nginx-v.txt | awk -F '=' '{print $2}'| head -1`
 			fi
 	     	fi
 	fi
        if [ -f "$NGINX_CONFIG" ]; then
                #echo " [+] Found config on $NGINX_CONFIG"
                cp $NGINX_CONFIG $NGINX_DIR
                ls -l $NGINX_CONFIG >> $NGINX_DIR/nginx_lsperm.txt
                
                #Process includes
		NGINX_INCLUDES=`grep -w include $NGINX_CONFIG | egrep -v '^#' | awk '{print $2}' | sed 's/;$//g' | sed 's/\"//g'`
                for includeconf in ${NGINX_INCLUDES}; do
                        #echo " [+]  will include $includeconf"
			if [ -f "$includeconf" ]; then
                        	cp ${includeconf} $NGINX_DIR/includes
                        	ls -l ${includeconf} >> $NGINX_DIR/nginx_lsperm.txt
			else
				dirconf=`dirname $NGINX_CONFIG`
				include2conf="$dirconf\/$includeconf"
				if [ -f "$include2conf" ]; then
					cp ${include2conf} $NGINX_DIR/includes
                                	ls -l ${include2conf} >> $NGINX_DIR/nginx_lsperm.txt
				else
					echo "Could not find ${includeconf}" >> $NGINX_DIR/nginx_gathering_errors.txt
				fi
			fi
                done
                
                echo  "done."
        else
                echo " [-] Config file $NGINX_CONFIG does not exist. Skipping"
        fi      
fi

if [ $IGNORE_TOMCAT -ne 1 ]; then

    echo "[+++] Searching Tomcat" >> $DEBUG_LOG
    echo "[+++] Searching Tomcat"
#!/bin/sh
[ ! -f /etc/vmware-release ] && {
    detect_unix_flavor

    SORT=`which sort`

    if [ "$OS" = "SunOS" ]; then

        version=`uname -a | awk '{ print $3 }'`
        if [ "$version" = "5.8" ]; then

            if [ -f "/usr/ucb/ps" ]; then

                tomcat_home=`/usr/ucb/ps -auxwww  | grep '/[^ ]*/java' | sed -n 's/^.\{1,\}-Dcatalina\.home=\([a-zA-Z0-9\._\/-]\{1,\}\).\{0,\}/\1/p'`
            else

                tomcat_home=`/usr/bin/ps auxwww  | grep '/[^ ]*/java' | sed -n 's/^.\{1,\}-Dcatalina\.home=\([a-zA-Z0-9\._\/-]\{1,\}\).\{0,\}/\1/p'`
            fi
        else

            if [ -f "/usr/ucb/ps" ]; then

                pid=`/usr/ucb/ps -auxwww | grep -- "-Dcatalina" | grep -v grep | awk '{ print $2 }'`
            else

                pid=`ps auxeww | grep -- "-Dcatalina" | grep -v grep | awk '{ print $2 }'`
            fi

            [ -n "$pid" ] && tomcat_home=`pargs -ae $pid | grep -- -Dcatalina.home | sed -n 's/^.\{1,\}-Dcatalina\.home=\(.\{1,\}\)$/\1/p'`
        fi
    else

        tomcat_home=`ps auxewww | grep '/[^ ]*/java' | sed -n 's/^.*-Dcatalina.home=\([^ ]\+\).*$/\1/p'`

    fi


    if [ -n "$SORT" ]; then

        tomcat_home=`printf "$tomcat_home\n" | sort -u`

    else

        tomcat_home=`remove_dup "$tomcat_home"`

    fi 

    if [ -n "$tomcat_home" ]; then

         for h in $tomcat_home; do
                [ -d "$h/conf" ] || continue

                col_tomcat=`echo $h | tr "/" "-" | cut -c2-`
                mkdir "$col_tomcat"

             cp $h/conf/*.xml "$col_tomcat" 2>> ./not-found.txt
             ls -lL "$h/conf" > "$col_tomcat/ls-lL-conf.txt" 2>> ./not-found.txt
             ls -lL "$h/logs" > "$col_tomcat/ls-lL-logs.txt" 2>> ./not-found.txt
             ls -lL "$h/bin"  > "$col_tomcat/ls-lL-bin.txt"  2>> ./not-found.txt
             ls -lL "$h/webapps" > "$col_tomcat/ls-lL-webapps.txt" 2>> ./not-found.txt
             ls -lL "$h/work/*/*" > "$col_tomcat/ls-lL-work.txt" 2>> ./not-found.txt

	# Collecting full information or not?
	if [ "$COPY_HASHES" -eq 0 ]; then

		if [ -s "$col_tomcat/tomcat-users.xml" ]; then
			cat "$col_tomcat"/tomcat-users.xml | sed -e "/password=\"[a-fA-F0-9]\{40\}\" /d;s/password=\".*\" /password=\"**********\" /g" > "$col_tomcat"/tomcat-users_nohashes.xml 2>/dev/null
			rm -f "$col_tomcat"/tomcat-users.xml 2>/dev/null
		fi

	fi

             if [ "$OS" = "SunOS" ]; then

                 #4.1 -> [TOMCAT_HOME]/server/lib/catalina.jar
                 #5.5 -> [TOMCAT_HOME]/server/lib/catalina.jar
                 #6.0 -> [TOMCAT_HOME]/lib/catalina.jar

                 if [ -f "$h/server/lib/catalina.jar" ]; then
                     catalina_jar="$h/server/lib/catalina.jar"
                 else
                     [ -f "$h/lib/catalina.jar" ] && catalina_jar="$h/lib/catalina.jar"
                 fi

                 [ -n "$catalina_jar" ] && {
                     unzip -p $catalina_jar org/apache/catalina/util/ServerInfo.properties | grep "^server.info" > "$col_tomcat/catalina-version.txt" 2>> ./not-found.txt
        }

             else
                 $h/bin/catalina.sh version > "$col_tomcat/catalina-version.txt" 2>> ./not-found.txt
             fi
         done
    fi
}
fi
# End Tomcat

    echo "[+++] Searching Sudo" >> $DEBUG_LOG
    echo "[+++] Searching Sudo"

SORT=`which sort`
UNIQ=`which uniq`

SUDO_DEFAULT_DIRS="
/etc
/usr/local/etc
/opt/csw/etc
"

DIRCOL=`pwd`
oldIFS=$IFS
IFS='
'

#Creating log dir
[ ! -d $DIRCOL/logs/ ] && mkdir $DIRCOL/logs

#log purpose only
gather_index=0

echo "[`date`] Getting less" >> $DIRCOL/logs/sudo.log
echo "[++++] Searching less program"
type less > $DIRCOL/has_less.txt 2>> ./not-found.txt

echo "[`date`] Gathering sudo configuration" >> $DIRCOL/logs/sudo.log
echo "[++++] Searching for Sudoers Configuration" 
sudo -V >> sudo-V.txt  2>> ./not-found.txt

for sudo_dir in $SUDO_DEFAULT_DIRS; do
   echo "[`date`] Searching default directory: ${sudo_dir}" >> $DIRCOL/logs/sudo.log
   if [ -f "$sudo_dir/sudoers" ]; then
      echo "[++++++] Found configuration at $sudo_dir" >> $DEBUG_LOG
      echo "[++++++] Copying Files" >> $DEBUG_LOG
      echo "[++++++] Found configuration at $sudo_dir"

      echo "[`date`] Sudoers ${sudo_dir} found, copying files." >> $DIRCOL/logs/sudo.log

      dir="sudo"`echo "$sudo_dir" | tr "/" "-"`
      dir="${DIRCOL}/${dir}/"
      mkdir "$dir"

      echo "[`date`] Copying $sudo_dir/sudoers to $dir" >> $DIRCOL/logs/sudo.log
      cp "$sudo_dir/sudoers" "$dir"

# Checking for Includes
      INCLUDES=`egrep '^#include ' $dir/sudoers | awk '{print $2}'`
      IFS=$oldIFS

      if [ -n "$INCLUDES" ]; then
         if [ ! -d "$dir/includes" ] ; then
            mkdir "$dir/includes"
	 fi
         for i in $INCLUDES; do
             echo "[`date`] Copying $i to $dir/includes" >> $DIRCOL/logs/sudo.log
             cp "$i" "$dir/includes/"
         done
      fi

      INCLUDEDIRS=`egrep '^#includedir ' $dir/sudoers | awk '{print $2}'`

      if [ -n "$INCLUDEDIRS" ]; then
         if [ ! -d "$dir/includedirs" ] ; then
            mkdir "$dir/includedirs"
         fi
         for i in $INCLUDEDIRS; do
             echo "[`date`] Copying $i to $dir/includedirs" >> $DIRCOL/logs/sudo.log
             cp -rf "$i" "$dir/includedirs/"
         done
      fi

    fi
done

gather_index=`expr $gather_index + 1`

IFS=$oldIFS
    echo "[+++] Searching SSH" >> $DEBUG_LOG
    echo "[+++] Searching SSH"

SORT=`which sort`
UNIQ=`which uniq`

SSH_DEFAULT_DIRS="
/opt/ssh/etc
/etc/ssh
/etc/sshd
/etc/openssh
/usr/local/etc
/usr/local/etc/ssh
/usr/local/etc/sshd
/usr/local/etc/openssh
"

sshInstances=`eval $PROCESSES | grep "^/[^ ]*/sshd"`

if [ -n "$SORT" ]; then

  #sort solaris compatibility => \n at the end of ssh instances string
  sshInstances=`printf "${sshInstances}\n" | sort -u`

else

  sshInstances=`remove_dup "$sshInstances"`

fi


DIRCOL=`pwd`
oldIFS=$IFS
IFS='
'

#Creating log dir
[ ! -d $DIRCOL/logs/ ] && mkdir $DIRCOL/logs

echo "[`date`] Number of SSH instances = `echo $sshInstances | wc -l`" >> $DIRCOL/logs/ssh.log

#log purpose only
gather_index=0

for instance in $sshInstances; do

    echo "[`date`] Gathering instance #${gather_index}" >> $DIRCOL/logs/ssh.log

    ssh_error=0

    cmd_ssh=`echo $instance | cut -d" " -f1`
    config=`echo $instance | awk ' {
        
        for(i = 2; i <= NF; i++) 
            if($i == "-f" && i < NF) {
                print $(i + 1) 
                break
            }
        }'`

    echo "[`date`] SSH command: ${cmd_ssh}" >> $DIRCOL/logs/ssh.log
    echo "[`date`] Configuration file (from process list): ${config}" >> $DIRCOL/logs/ssh.log

    if [ -n "$config" ] && [ -f "$config" ]; then

        configDir=`echo $config | sed -n "s;^\(/[^ ]*\)/.*$;\1;p"`
        dir="ssh"`echo $configDir | tr "/" "-"`

        echo "[`date`] Configuration directory (from process list): ${configDir}" >> $DIRCOL/logs/ssh.log

    else

        configDir=`strings $cmd_ssh | grep sshd_config |sed -n "s;^\(/[^ ]*\)/.*$;\1;p"`

        if [ -n "$UNIQ" ]; then

          configDir=`printf "$configDir" | uniq`

        else

          configDir=`remove_dup "$configDir"`

        fi

        echo "[`date`] Configuration directory (from binary dump): ${configDir}" >> $DIRCOL/logs/ssh.log

        config="$configDir/sshd_config"
        dir="ssh"`echo $configDir | tr "/" "-"`

    fi

    if [ -z "$configDir" ] || [ ! -d "$configDir" ]; then
         configDir="$configDir not found."
         ssh_error=1

         echo "[`date`] Configuration Directory no found or not exists: ${configDir}" >> $DIRCOL/logs/ssh.log
    fi

    if [ -z "$config" ] || [ ! -f "$config" ]; then
        config="$config not found."
        ssh_error=1
        echo "[`date`] Configuration Directory not found or not exists: ${config}" >> $DIRCOL/logs/ssh.log
    fi

    if [ !  -x "$cmd_ssh" ]; then
          continue;
        echo "[`date`] SSH binary (${cmd_ssh}) has no execution permission" >> $DIRCOL/logs/ssh.log
    fi

    echo "[++++] Found SSH Daemon instance at $cmd_ssh" >> $DEBUG_LOG
    echo "[++++] Found SSH Daemon instance at $cmd_ssh"

    echo "[`date`] Found SSH Daemon instance at ${cmd_ssh}" >> $DIRCOL/logs/ssh.log

    if [ "$ssh_error" = "1" ]; then
        echo "[+++++] Configuration Directory not found." >> $DEBUG_LOG
        echo "[+++++] Searching default configurations..." >> $DEBUG_LOG
        echo "[+++++] Configuration Directory not found."
        echo "[+++++] Searching default configurations..."

        echo "[`date`] Configuration Directory not found, searching default configurations..." >> $DIRCOL/logs/ssh.log
 
        for ssh_dir in $SSH_DEFAULT_DIRS; do
         echo "[`date`] Searching default directory: ${ssh_dir}" >> $DIRCOL/logs/ssh.log
            if [ -d "$ssh_dir" ]; then
                echo "[++++++] Found Directory at $ssh_dir" >> $DEBUG_LOG
                echo "[++++++] Copying Files" >> $DEBUG_LOG
                echo "[++++++] Found Directory at $ssh_dir"
                echo "[++++++] Copying Files"

           echo "[`date`] ${ssh_dir} found, copying files." >> $DIRCOL/logs/ssh.log

                dir="ssh"`echo "$ssh_dir" | tr "/" "-"`
                dir="${DIRCOL}/${dir}-default/"
                mkdir "$dir"

          echo "[`date`] Copying $ssh_dir/sshd_config to $dir" >> $DIRCOL/logs/ssh.log
                cp "$ssh_dir/sshd_config" "$dir"

          echo "[`date`] Copying $ssh_dir/ssh_config to $dir" >> $DIRCOL/logs/ssh.log
                cp "$ssh_dir/ssh_config"  "$dir"

          echo "[`date`] Gathering SSH version ($dir/sshd-v.txt) " >> $DIRCOL/logs/ssh.log
                $cmd_ssh -v 1> "$dir/sshd-v.txt" 2>> "$dir/sshd-v.txt"                

          echo "[`date`] SSH Version:" >> $DIRCOL/logs/ssh.log
          $cmd_ssh -v >> $DIRCOL/logs/ssh.log 2>> $DIRCOL/logs/ssh.log


            fi
        done
    else
        echo "[+++++] Configuration Directory: $configDir" >> $DEBUG_LOG
        echo "[+++++] Configuration File: $config" >> $DEBUG_LOG
        echo "[+++++] Configuration Directory: $configDir"
        echo "[+++++] Configuration File: $config"

        mkdir "${DIRCOL}/$dir"

        echo "[`date`] Gathering SSH Version: $dir/sshd-v.txt " >> $DIRCOL/logs/ssh.log
        $cmd_ssh -V 2>> "${DIRCOL}/$dir/sshd-v.txt" 1>> "${DIRCOL}/$dir/sshd-v.txt"
        echo "[`date`] SSH Version: `cat ${DIRCOL}/$dir/sshd-v.txt`" >> $DIRCOL/logs/ssh.log

        echo "[`date`] Copying $config to $dir" >> $DIRCOL/logs/ssh.log
        cp "$config" "${DIRCOL}/$dir/"

        echo "[`date`] Copying $configDir/ssh_config to $dir" >> $DIRCOL/logs/ssh.log
        cp "$configDir/ssh_config"  "${DIRCOL}/$dir/"
    fi

    gather_index=`expr $gather_index + 1`
done

IFS=$oldIFS

    echo "[+++] Searching SNMP" >> $DEBUG_LOG
    echo "[+++] Searching SNMP"
###################
detect_unix_flavor

old_gathering () {

  ###echo $OS

  case $OS in

    'AIX')
      snmpd_confs="/etc/snmpd.conf"
      ;;

    'Darwin')
      snmpd_confs="/etc/snmp/conf/snmpd.conf /etc/snmp/snmpd.conf"
      ;;

    'FreeBSD')
      snmpd_confs=""
      proc_list="`ps -A`"      

      ( echo "$proc_list" | grep -q "[/ ]bsnmpd\([[:blank:]].*\)\{0,1\}$" ) && {
             snmpd_confs="/etc/snmpd.config"
      } 
      
      ( echo "$proc_list" | grep -q "[/ ]snmpd\([[:blank:]].*\)\{0,1\}$" ) && {
             snmpd_confs="/usr/local/etc/snmpd.conf $snmpd_confs"
      }
      ;;

    'OpenBSD')
      snmpd_confs="/etc/snmp/snmpd.conf /etc/snmpd-etc.conf"
      ;;

    'Qnx')
      snmpd_confs="/etc/snmp/snmpd.conf /etc/snmpd.conf"
      ;;

    'SunOS')
      snmpd_confs="/etc/snmp/conf/snmpd.conf /etc/snmp/snmpd.conf"
      ;;

    'Linux')
      snmpd_confs="/etc/snmpd.conf /etc/snmp/snmpd.conf"
      ;;

    'HP-UX')
      snmpd_confs="/etc/SnmpAgent.d/snmpd.conf /etc/snmpd.conf"
      ;;

    *)
      snmpd_confs="/etc/snmpd.conf /etc/snmpd.conf /etc/snmp/conf/snmpd.conf /etc/snmp/snmpd.conf /etc/snmpd-etc.conf"
      ;;

  esac

  for file in $snmpd_confs; do
    echo "[+++++] Looking for the configuration in: $file"
    [ -f "$file" ] && {
      cp $file ./snmpd.conf 2>>./not-found.txt
      break
    }
  done

  unset snmpd_confs file

}

old_gathering

### NEW SNMP GATHERING

new_gathering () {

  [ $# -lt 1 ] && return 1

  snmp_instances=$1

  oldifs=$IFS
IFS='
'
  for process in $snmp_instances; do

    IFS=$oldifs

    pid=`echo "$process" | awk '{ print $2 }'` 
    #FIXME - Se for solaris 10, precisa ser o campo 12
    cmd=`echo "$process" | awk '{ print $11 }'` 

    #If -c option is provided, the process can tell us where is the configuration file.
    conf_dir=`echo "$process" | sed -n 's/.\{1,\}-c \([0-9a-zA-Z\._\/]\{1,\}\).\{0,\}/\1/p'`

    if [ -n "$conf_dir" ] && [ -f "$conf_dir/snmpd.conf" ]; then
      snmp_conf="$conf_dir/snmpd.conf"
    else

      absolute_path=1
      echo "$cmd" | grep "^/" > /dev/null && absolute_path=0

      [ $absolute_path -eq 1 ] && cmd=`pwdx $pid | awk '{ print $2 }'`/$cmd

      libnetsnmp=`ldd $cmd | grep libnetsnmp.so | awk '{ print $3 }'`

      [ -n "$libnetsnmp" ] && {
        conf_dirs=`strings $libnetsnmp | grep -i "\/snmp"`
        for dir in $conf_dirs; do
          [ -d "$dir" ] && {
        [ -f "$dir/snmpd.conf" ] && {
          snmp_conf="$dir/snmpd.conf"
          break
        }
          }
        done
      }

      [ -z "$snmp_conf" ] && {
        libnetsnmpmibs=`ldd $cmd | grep libnetsnmpmibs.so | awk '{ print $3 }'`
        [ -f "$libnetsnmpmibs" ] && {
          conf_dir=`strings $libnetsnmpmibs | grep -i sysconf | sed -n "s/.\{1,\}'--sysconfdir=\([a-z\/A-Z0-9_\.]\{1,\}\)'.\{1,\}/\1/p"`

          [ -f "$conf_dir/snmpd.conf" ] && snmp_conf="$conf_dir/snmpd.conf"
        }
      }

    fi 

    [ -n "$snmp_conf" ] && {
      gdir=`echo "$cmd" | tr "/" "-"`
      mkdir -p "./SNMP/$gdir/"
      cp $snmp_conf "./SNMP/$gdir/" 2>>./not-found.txt
    }

  #FIXME - unset variables
IFS='
'
  done

  IFS=$oldifs
  #FIXME - unset variables

  return 0

}

case $OS in
  'Linux')
      snmp_instances=`$PS_LINUX | grep snmpd | grep -v grep`
      new_gathering "$snmp_instances"
    ;;

  'SunOs')
      snmp_instances=`$PS_SUNOS | grep snmpd | grep -v grep`
      new_gathering "$snmp_instances"
    ;;

  *)
    ;;
esac

IFS=$oldifs

    echo "[+++] Searching Postfix" >> $DEBUG_LOG
    echo "[+++] Searching Postfix"

collect_original_file_perm () {

        original_file="$1"
        is_sym=`ls -l $original_file | awk '$0 ~ /^l........./ { print $NF }'`
        found_file="no"
        count="0"

        if [ -n "$is_sym" ]; then

                while [ "$found_file" = "no" ]; do

                        [ ! -f "$is_sym" ] && break
                        [ "$count" -gt "4" ] && break

                        count=`expr  "$count" \+ 1`
                        check_file="$is_sym"
                        is_sym=`ls -l $check_file | awk '$0 ~ /^l........./ { print $NF }'`

                        if [ -z "$is_sym" ]; then

                                file=`ls -l $check_file | awk '$0 ~ /^\-........./ { print $NF }'`
                                found_file="yes"
                        fi

                done

                echo "$file"
        else

                echo "$original_file"
        fi
}

#########################################
# Gathering only if the system is Linux
#########################################
if [ "$OSVER" = Linux ]; then

POSTFIX_DIR="./Postfix"
[ -d "$POSTFIX_DIR" ] && rm -rf $POSTFIX_DIR
postfix_exec=""
postfix_ps_1=`ps -f -C master --no-heading | awk '{ print $8 }'`
postfix_ps_2=`ps -f -C qmgr --no-heading | awk '{ print $8 }'`
postfix_ps_3=`ps -f -C pickup --no-heading | awk '{ print $8 }'`
[ -n "$postfix_ps_1" -a -n "$postfix_ps_2" -a -n "$postfix_ps_3" ] && {
    [ -f "/sbin/postfix" ] && postfix_exec="/sbin/postfix"
    [ -f "/sbin/postconf" ] && postfix_conf="/sbin/postconf"
    [ -f "/bin/postfix" ] && postfix_exec="/bin/postfix"
    [ -f "/bin/postconf" ] && postfix_conf="/bin/postconf"
    [ -f "/usr/sbin/postfix" ] && postfix_exec="/usr/sbin/postfix"
    [ -f "/usr/sbin/postconf" ] && postfix_conf="/usr/sbin/postconf"
    [ -f "/usr/bin/postfix" ] && postfix_exec="/usr/bin/postfix"
    [ -f "/usr/bin/postconf" ] && postfix_conf="/usr/bin/postconf"
    [ -f "/usr/local/sbin/postfix" ] && postfix_exec="/usr/local/sbin/postfix"
    [ -f "/usr/local/sbin/postconf" ] && postfix_conf="/usr/local/sbin/postconf"
    [ -f "/usr/local/bin/postfix" ] && postfix_exec="/usr/local/bin/postfix"
    [ -f "/usr/local/bin/postconf" ] && postfix_conf="/usr/local/bin/postconf"
}

[ -n "$postfix_exec" -a -n "$postfix_conf" ] && {
    # Creating data gathering directory.
    mkdir $POSTFIX_DIR
    # Getting version and saving the output
    version=`$postfix_conf -d 2>/dev/null| awk '/^\ *mail_version/ { print $0 }' | sed 's/\ *mail_version\ *=\ *//g'`
    echo $version > $POSTFIX_DIR/version
    
    # Getting config directory
    POSTFIX_CONFIG_DIR=`$postfix_conf -d 2>/dev/null| awk '/^\ *config_directory/ { print $0}' | sed 's/\ *config_directory\ *=\ *//g'`
    
    # Getting main.cf
    [ -f "${POSTFIX_CONFIG_DIR}/main.cf" ] && {
        cp ${POSTFIX_CONFIG_DIR}/main.cf $POSTFIX_DIR
    }

    # Getting Sendmail path
    POSTFIX_SENDMAIL_PATH=`$postfix_conf -d 2>/dev/null| awk '/^\ *sendmail_path/ { print $0}' | sed 's/\ *sendmail_path\ *=\ *//g'`

    # Getting Sendmail perm
    [ -f "$POSTFIX_SENDMAIL_PATH" ] && {

	file=`collect_original_file_perm "$POSTFIX_SENDMAIL_PATH"`
        sendmail_permissions=`ls -la $file`
        echo $sendmail_permissions > $POSTFIX_DIR/sendmail_permissions
    }

    unset POSTFIX_SENDMAIL_PATH
    unset sendmail_permissions
    unset POSTFIX_CONFIG_DIR
    unset version
}
unset POSTFIX_DIR
unset postfix_ps_1
unset postfix_ps_2
unset postfix_ps_3
unset postfix_exec
unset postfix_conf

fi
#########################################
    echo "[+++] Searching JBoss Application Server" >> $DEBUG_LOG
    echo "[+++] Searching JBoss Application Server"
#!/bin/sh
#===============================================================================
#
#          FILE:  JBoss
# 
#   DESCRIPTION:  JBoss Application Server
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  
#
#                 * ATENCAO! *
#                 Uso Restrito a Tecnicos da Proteus
#
#        AUTHOR:  David Pinheiro, david dot pinheiro at proteus dot com dor br
#       COMPANY:  Proteus Security Systems
#       VERSION:  0.1
#       CREATED:  06/26/2007 08:48:00 AM BRT
#      REVISION:  3 
#     COPYRIGHT:  Copyright(c) 2007 - Proteus Security Systems
#===============================================================================


#===  FUNCTION  ================================================================
#          NAME: coleta_jboss
#   DESCRIPTION: -- 
#    PARAMETERS: -- 
#       RETURNS: 0 = success; any value > 0 = failure 
#===============================================================================
coleta_jboss () {

  #Assumindo que o shell ja esta posicionado no diretorio de coleta

  #Retrieve process id and jboss home directory from process list
  
  if [ "$OS" = "SunOS" ]; then
    sunos_version=`uname -a | awk '{print $3}'`

    if [ "$sunos_version" = "5.8" ]; then
      jboss_pids=`eval $PS_COMMAND | grep org.jboss.Main | grep -v grep | sed -n 's/^[a-zA-Z0-9]\{1,\}[ \t]\{1,\}\([0-9]\{1,\}\).\{1,\}classpath \(.\{1,\}\)bin\/run.jar.\{1,\}/\1:\2/p'`
    else
      jboss_pids=`eval $PS_COMMAND | grep org.jboss.Main | grep -v grep | awk '{ print $2 }'`
    fi

  else
    #It will include the pid and jboss home ":" separated
    #TODO - retrieve pid only
    jboss_pids=`$PS_COMMAND | grep org.jboss.Main | grep -v grep | sed -n 's/^[a-zA-Z0-9]\{1,\}[ \t]\{1,\}\([0-9]\{1,\}\).\{1,\}classpath \(.\{1,\}\)bin\/run.jar.\{1,\}/\1:\2/p'`
  fi 

  echo "[`date`] Processos JBoss:" >> logs/jboss.log
  printf "%s\n" "$jboss_pids" >> logs/jboss.log

  index=0

  oldifs=$IFS
IFS='
'
  for pid in $jboss_pids; do

    if [ "$OS" = "SunOS" ]; then

      if [ "$sunos_version" = "5.8" ]; then
        jboss_home=`echo $pid | cut -d: -f2` 
        pid=`echo $pid | cut -d: -f1` 
      else
        jboss_home=`eval pargs -ea ${pid} | grep "/bin/run.jar" | sed -n "s#argv\[[0-9]\{1,\}\]: \(.\{1,\}\)/bin/run.jar.\{1,\}#\1#p"`
      fi
    else

      jboss_home=`echo $pid | cut -d: -f2` 
      pid=`echo $pid | cut -d: -f1` 

    fi

    echo "[`date`] Coletando JBoss #${index}" >> logs/jboss.log
    echo "[`date`] pid=${pid}" >> logs/jboss.log
    echo "[`date`] jboss_home=${jboss_home}" >> logs/jboss.log

    index=`expr ${index} + 1`
    TARGET_DIR="jboss/instance${index}"

    if [ ! -d $TARGET_DIR ]; then

      mkdir -p $TARGET_DIR 

    fi 

    #Coletando versao do JBOSS e da JDK
    if [ -f "$jboss_home/bin/run.sh" ]; then

      JBOSS_VERSION=`eval $jboss_home/bin/run.sh --version | grep "^JB[oss|OSS].*[bB]uild.*date"`

      echo "[`date`] JBOSS_VERSION=${JBOSS_VERSION}" >> logs/jboss.log

      echo $JBOSS_VERSION > $TARGET_DIR/jboss_version 

      java_bin=`eval $jboss_home/bin/run.sh --version | sed -n "s/[ \t]\{1,\}JAVA: \(.\{1,\}\)/\1/p"` 

      echo "[`date`] java_bin=${java_bin}" >> logs/jboss.log

      if [ ! -z "$java_bin" ]; then

        JDK_VERSION=`eval $java_bin -version 2>&1 | grep "^.*version"`

        echo "[`date`] JDK_VERSION=${JDK_VERSION}" >> logs/jboss.log

        echo $JDK_VERSION > $TARGET_DIR/jdk_version 

      fi

    fi

    #Processo JBOSS
    #FIXME - If the process string is too long, some OS may truncate the string.
    #Need to improve this code usind a pargs (sunos) like solution.
    #Obs.: Analisys must follow this change.
    eval $PS_COMMAND | grep org.jboss.Main | grep ${pid} | grep -v grep  > $TARGET_DIR/ps_jboss 2>> logs/jboss.err.log

    #JMX Console habilitada
    ls -lR $jboss_home/server/default/deploy/jmx-console.war > $TARGET_DIR/jmx-console.war.ls 2>> logs/jboss.err.log

    #Acesso anonimo a JMX console
    cat $jboss_home/server/default/deploy/jmx-console.war/WEB-INF/web.xml > $TARGET_DIR/web.xml 2>> logs/jboss.err.log

    #Senha padrao do admin do JMX console
    jmx_user_file="$jboss_home/server/default/conf/props/jmx-console-users.properties"
    [ -f "$jmx_user_file" ] && {
    
        cat $jmx_user_file > $TARGET_DIR/jmx-console-users.properties 2>> logs/jboss.err.log
        echo "$jmx_user_file" > $TARGET_DIR/jmx-console-users.properties_path.txt 2>> logs/jboss.err.log
    }

    #Senha padrao do admin do web-console
    web_console_user_file="$jboss_home/server/default/deploy/management/console-mgr.sar/web-console.war/WEB-INF/classes/web-console-users.properties"
    [ -f "$web_console_user_file" ] && {

        cat $web_console_user_file > $TARGET_DIR/web-console-users.properties 2>> logs/jboss.err.log
	echo "$web_console_user_file" > $TARGET_DIR/web-console-users.properties_path.txt 2>> logs/jboss.err.log
    }

    #Acesso anonimo ao Web Console
    cat $jboss_home/server/default/deploy/management/console-mgr.sar/web-console.war/WEB-INF/web.xml > $TARGET_DIR/web-console.web.xml 2>> logs/jboss.err.log

    #Web Console habilitado
    ls -lR $jboss_home/server/default/deploy/management/ > $TARGET_DIR/web-console.management.ls 2>> logs/jboss.err.log

    #Permissao dos arquivos de configuracao do JBoss
    ls -ld $jboss_home/server/default/conf/* > $TARGET_DIR/jboss.conf.files.ls 2>> logs/jboss.err.log

    #Permissao do script de shutdown do JBoss
    ls -l $jboss_home/bin/shutdown.sh > $TARGET_DIR/shutdown.sh.ls 2>> logs/jboss.err.log

    #Permissao dos arquivos de log do JBoss
    ls -ld $jboss_home/server/default/log/* > $TARGET_DIR/jboss.log.files.ls 2>> logs/jboss.err.log

  done
  IFS=$oldIFS

  return 0
}

[ ! -d ./logs/ ] && mkdir logs

detect_unix_flavor
echo "[`date`] OS=${OS}" >> logs/jboss.log
detect_ps
echo "[`date`] PS_COMMAND=${PS_COMMAND}" >> logs/jboss.log

coleta_jboss

echo "[`date`] Saida da funcao coleta_jboss: $?" >> logs/jboss.log

    echo "[+++] Searching WebSphere" >> $DEBUG_LOG
    echo "[+++] Searching WebSphere"
#!/bin/sh

gen_temp_script_for_was_instance() {

        unset mktemp_test
        server_name="$1"

        mktemp_test=`which mktemp 2>/dev/null`
        if [ -n "$mktemp_test" ]; then

                temp_file=`mktemp /tmp/XXXXXXX`
        else

                rm -rf /tmp/.prot/
                mkdir -p /tmp/.prot/websphere/
                chmod 755 /tmp/.prot/websphere/
                temp_file="/tmp/.prot/websphere/.websphere.temp"
                touch "$temp_file"
        fi      
        chmod 755 "$temp_file" 

        cat <<EOF > "$temp_file"
#import re
srv = AdminControl.completeObjectName( 'type=Server,process=$server_name,*' )

if srv == '' :

        print "Server doesn't exist... Aborting!"
else :
        info = srv.split( ',' )
        data = {}
        name = ''
        
        for field in info :
                ( key, val ) = field.split( '=' )
                data[ key ]  = val

        name  = '/Cell:' + data[ 'cell' ] + '/Node:' + data[ 'node' ] + '/Server:' + data[ 'process' ] + '/'
        id = AdminConfig.getid ( name )

        session_manager = AdminConfig.list( 'SessionManager', id )
        att = AdminConfig.showAttribute( session_manager, 'enableSecurityIntegration' )
        print 'enableSecurityIntegration ' + att
        print '\n'

        tuning_params = AdminConfig.list( 'TuningParams', id )
        att = AdminConfig.showAttribute( tuning_params, 'invalidationTimeout' )
        print 'invalidationTimeout ' + att
        print '\n'

        att = AdminConfig.show( id, 'developmentMode' )
        #att = re.sub( '\]|\[', '', att )
        print att
        print '\n'

        security = AdminConfig.list( 'Security' )
        att = AdminConfig.showAttribute( security, 'enforceJava2Security' )
        print 'enforceJava2Security ' + att
        print '\n'

        att = AdminConfig.showAttribute( security, 'cacheTimeout' )
        print 'cacheTimeout ' + att
        print '\n'

        att = AdminTask.isGlobalSecurityEnabled()
        print 'enableGlobalSecurity ' + att
        print '\n'

        att = AdminTask.isAppSecurityEnabled()
        print 'appSecurityEnabled ' + att
        print '\n'

        app_list = AdminApp.list()
        #app_list = re.sub( '\n', ' ', app_list )
        print 'Installed Applications: ' + app_list
        print '\n'

        version =  AdminControl.getAttribute( srv, 'serverVersion' )
        #version = re.findall( 'Version.*[0-9].*', version )
        print version
        print '\n'

        port_list = AdminTask.listServerPorts( '$server_name' )
        print 'Server Ports: ' + port_list
        print '\n'
EOF

        echo "$temp_file"
}

get_websphere() {
	
    echo "[+++] Searching WebSphere" >> $DEBUG_LOG
    echo "[+++] Searching WebSphere"

        case "$OSVER" in

                "Linux")

                        ps_command="ps auxewww"
                ;;

                "AIX")

                        ps_command="ps auxeww"
                ;;

                *)

                        #system is not supported yet
                        return
                ;;
        esac

	IFS="
"

        instances=`eval "$ps_command" | egrep java | egrep -v egrep | sed -n 's/^.*WAS_HOME=\([^ ]\{1,\}\).*$/\1/p' | tr " " "\n" | sort -u`
        [ -n "$instances" ] && mkdir -p websphere/
        eval "$ps_command" 2>/dev/null | egrep "WAS_HOME" | egrep -v egrep 2>/dev/null > websphere/.ps_output.txt

        for instance in ${instances}; do


                echo "[++++] Found WebSphere Server instance at $instance" >> $DEBUG_LOG
                echo "[++++] Found WebSphere Server instance at $instance"

                wsadmin_bin="$instance/bin/wsadmin.sh"
                [ ! -f "$wsadmin_bin" ] && {

                        echo "[++++++++] Error running \"wsadmin.sh\" script - File not found! Aborting... "
                        rm -rf $gather_instance_dir
                        continue
                }

                gather_instance_dir=`echo "$instance" | sed 's/\//__/g'`
                gather_instance_dir="./websphere/$gather_instance_dir/"
                mkdir -p $gather_instance_dir

                running_by=`cat websphere/.ps_output.txt | egrep "WAS_HOME=$instance" | awk '{ print $1 }' | sort -u | head -n1`

                [ -z "$running_by" ] && continue

                if [ "$running_by" == "root" ]; then

			sh $wsadmin_bin -lang jacl -conntype NONE -c "\$AdminConfig list Server" | awk -F"(" ' match($0,/.*cells.*nodes.*servers.*/) { print $1 } ' > $gather_instance_dir/.servers.txt
                else

                        servers=`su $running_by -c "cd /tmp/; sh $wsadmin_bin -lang jacl -conntype NONE -c '\\$AdminConfig list Server' 2>/dev/null" | awk -F'(' ' match($0,/.*cells.*nodes.*servers.*/) { print $1 } '`
                        echo "$servers" | tr " " "\n" | sort -u >$gather_instance_dir/.servers.txt
                fi

                echo_n "[++++++++] Collecting information from: "
                for was_server in `cat $gather_instance_dir/.servers.txt | tr " " "\n" | sort -u`; do

                        #if empty, probably this app_server is not active, but only listed as existent
                        running_by=`cat websphere/.ps_output.txt | egrep "WAS_HOME=$instance" | egrep "$was_server" | awk '{ print $1 }' | sort -u | head -n1`
                        [ -z "$running_by" ] && continue

                        echo_n "$was_server "
                        mkdir -p $gather_instance_dir/$was_server/
                        echo "$running_by" > $gather_instance_dir/$was_server/instance_run_by.txt
                        temp_file=`gen_temp_script_for_was_instance "$was_server"`

			unset general_security_confs
			non_root="0"
			test_user=`awk -F: ' $3 == 0 { print $1 }' /etc/passwd 2>/dev/null | sort -u | egrep "^$running_by$"`
                        if [ "$running_by" == "root" -o -n "$test_user" ]; then

                                echo | sh $wsadmin_bin -conntype SOAP -lang jython -f $temp_file 2>/dev/null > $gather_instance_dir/$was_server/general_security_confs.txt #avoid issues when waiting for <enter>
				[ "$?" != "0" ] && {

					echo "[++++++++] Error running \"wsadmin.sh\" script (1) - Unnexpected status! Aborting... "
					echo "$was_server" >> $gather_instance_dir/.instances_with_errors.txt
					rm -f $gather_instance_dir/$was_server/general_security_confs.txt 2>/dev/null
					rm -f $gather_instance_dir/$was_server/instance_run_by.txt 2>/dev/null
                                	continue
				}
                        else

                                general_security_confs=`su "$running_by" -c "cd /tmp/ ; echo | sh $wsadmin_bin -conntype SOAP -lang jython -f $temp_file 2>/dev/null "` #avoid issues when waiting for <enter>
				non_root="1"
                        fi

                        if [ -z "$general_security_confs" -a "$non_root" == "1" ]; then

				echo "[++++++++] Error running \"wsadmin.sh\" script (2) - Unnexpected status! Aborting... "
				echo "$was_server" >> $gather_instance_dir/.instances_with_errors.txt
				rm -f $gather_instance_dir/$was_server/general_security_confs.txt 2>/dev/null
				rm -f $gather_instance_dir/$was_server/instance_run_by.txt 2>/dev/null
                                continue
                        else

                                unset test_error
                                [ "$running_by" != "root" ] && {

                                        test_error=`echo $general_security_confs | egrep -i "(Cannot establish.*connection to host|(AdminTask object is|AdminControl service) not available)"`
                                        if [ -z "$test_error" ]; then

                                                echo "$general_security_confs" > $gather_instance_dir/$was_server/general_security_confs.txt
                                        else

						echo "[++++++++] Error running \"wsadmin.sh\" script (3) - Unnexpected status! Aborting... "
                                                echo "$was_server" >> $gather_instance_dir/.instances_with_errors.txt
                                                rm -f $gather_instance_dir/$was_server/general_security_confs.txt 2>/dev/null
                                                rm -f $gather_instance_dir/$was_server/instance_run_by.txt 2>/dev/null
                                                continue
                                        fi
                                }
                        fi
                done

                echo ""
                echo "[++++++++] Now collecting information from: WAS_HOME (files/directories permissions)"
                mkdir -p $gather_instance_dir/was_admin_dir_perms/
                gather_instance_dir="$gather_instance_dir/was_admin_dir_perms/"

                ls -ld $instance/profiles/*/properties/soap.client.props 2>/dev/null > $gather_instance_dir/soap.client.props_permissions.txt
                ls -ld $instance/profiles/*/logs/* 2>/dev/null > $gather_instance_dir/logs_dir_permissions.txt
                ls -ld $instance/profiles/*/etc/* 2>/dev/null > $gather_instance_dir/etc_dir_permissions.txt
                ls -ld $instance/profiles/*/config/* 2>/dev/null > $gather_instance_dir/config_dir_permissions.txt
                ls -ld $instance/profiles/*/bin/* 2>/dev/null > $gather_instance_dir/bin_dir_permissions.txt
        done

        rm -f "$temp_file" 
	rm -rf /tmp/.prot/
        unset instance instances gather_instance_dir ps_command temp_file was_server running_by found_cred_conf local_cred_file test_return

}

if [ "$EXEC_WEBSPHERE" = yes ]; then
        get_websphere
fi

collect_named() {

        mkdir -p ./cache/
        if [ -f "ps-auxww.txt" ]; then

		cat ps-auxww.txt | egrep -v "[a-zA-Z0-9_]+named" | egrep "([\/]|[ \t])+named([ \t]+|[ \t]*$)" | egrep -v egrep > ./cache/bind-processes

                elif [ -f "ps-ef.txt" ]; then

			cat ps-ef.txt | egrep -v "[a-zA-Z0-9_]+named" | egrep "([\/]|[ \t])+named([ \t]+|[ \t]*$)" | egrep -v egrep > ./cache/bind-processes

        else

                if [ "$OS" = "FreeBSD" ] || [ "$OS" = "OpenBSD" ]; then

			ps -axwwww | egrep -v "[a-zA-Z0-9_]+named" | egrep "([\/]|[ \t])+named([ \t]+|[ \t]*$)" | egrep -v egrep > ./cache/bind-processes
                else

			ps -ef | egrep -v "[a-zA-Z0-9_]+named" | egrep "([\/]|[ \t])+named([ \t]+|[ \t]*$)" | egrep -v egrep > ./cache/bind-processes
                fi
        fi

        echo "[+++] Searching Bind/Named Server instances" >>$DEBUG_LOG
        echo "[+++] Searching Bind/Named Server instances"

        named_inst_counter="0"
        IFS_bkp="$IFS"
        IFS="
"

        for named_line in `cat ./cache/bind-processes`; do

                mkdir -p ./named/instances/

                named_inst_counter=`expr $named_inst_counter \+ 1`
                mkdir -p ./named/instances/$named_inst_counter

                named_user=`echo "$named_line" | awk '{ print $1 }'`
                echo "$named_user" > ./named/instances/$named_inst_counter/named-user.txt

                named_proc=`echo "$named_line"`
                echo "$named_proc" > ./named/instances/$named_inst_counter/named-proc.txt

                detect_chroot=`echo "$named_line" | egrep "named[ \t]+.*\-t[ \t]+.*"`
                if [ -n "$detect_chroot" ]; then

                        #named is chrooted
                        chroot_dir=`echo "$named_line" | sed -n 's/^.*\-t[ \t]\{1,\}\([^ ]\{1,\}\).*$/\1/p'`
                        echo "$chroot_dir" > ./named/instances/$named_inst_counter/named-chroot_dir.txt

                        named_bin=`echo "$named_line" | awk '{ print $11 }' | sed 's/[ \t]\{0,\}$//g'`
                        echo "$named_bin" > ./named/instances/$named_inst_counter/named-bin.txt

                        if [ -n "$named_bin" -a -f "$named_bin" ]; then

                                named_version=`$named_bin -v | egrep BIND`
                        else

                                named_version="Version not detected"
                        fi
                        echo "$named_version" > ./named/instances/$named_inst_counter/named-version.txt

                        conf_file=`echo "$named_line" | sed -n 's/^.*\-c[ \t]\{1,\}\([^ ]\{1,\}\).*$/\1/p'`

                        [ ! -f "$chroot_dir/$conf_file" ] && conf_file="etc/named/named.conf"
                        [ ! -f "$chroot_dir/$conf_file" ] && conf_file="etc/bind/named.conf"
                        conf_dir=`echo "$chroot_dir/$conf_file" | awk -F'/' '{ OFS="/"; $NF=""; print $0 }'`
                        [ -n "$conf_dir" -a -d "$conf_dir" ] && ls -dl "$conf_dir"/* > ./named/instances/$named_inst_counter/named-perm.txt
                        [ ! -f "./named/instances/$named_inst_counter/named-perm.txt" ] && touch ./named/instances/$named_inst_counter/named-perm.txt

                        echo "[+++++] Looking for configuration file in: $chroot_dir/$conf_file"
                        cat "$chroot_dir/$conf_file" > ./named/instances/$named_inst_counter/named.conf
                        echo "$chroot_dir/$conf_file" > ./named/instances/$named_inst_counter/named.conf-path.txt


                        [ -n "$conf_file" -a -f "$chroot_dir/$conf_file" ] && {

                                additional_conf_includes=`awk '$1 ~ /^([[:blank:]]|[[:space:]])*include([[:blank:]]|[[:space:]])*/ { print $2 }' "$chroot_dir/$conf_file" | sed 's/\"//g ; s/\;//g'`
                                for each_add_conf_include in ${additional_conf_includes}; do

					mkdir -p ./named/instances/$named_inst_counter/includes/ 
					each_add_conf_include_2=`echo "$each_add_conf_include" | sed 's/[/]/\_/g'`
				        cp "$each_add_conf_include" ./named/instances/$named_inst_counter/includes/"$each_add_conf_include_2"

                                        temp_dir=`awk '$1 ~ /^([[:blank:]]|[[:space:]])*(directory|managed-keys-directory)/ { print $2 }' "$each_add_conf_include" | sed 's/\"//g ; s/\;//g'`
                                        temp_dirs=`echo "$temp_dir"; echo "$temp_dirs"`
                                done

                                additional_conf_dirs=`awk '$1 ~ /^([[:blank:]]|[[:space:]])*(directory|managed-keys-directory)/ { print $2 }' "$chroot_dir/$conf_file" | sed 's/\"//g ; s/\;//g'`
                                additional_conf_dirs=`echo "$additional_conf_dirs $temp_dirs" | sed 's/ /\n/g' | sort -u`
                                for each_add_conf_dir in ${additional_conf_dirs}; do

                                        ls -ld "$chroot_dir/$each_add_conf_dir/"* >> ./named/instances/$named_inst_counter/named-perm.txt 2>>./not-found.txt
                                done
                        }

                else

                        #named is non chrooted
                        conf_file=`echo "$named_line" | sed -n 's/^.*\-c[ \t]\{1,\}\([^ ]\{1,\}\).*$/\1/p'`
                        [ -z "$conf_file" ] && {

                                [ -z "$conf_file" ] && [ -f "/etc/bind/named.conf" ] && conf_file="/etc/bind/named.conf"
                                [ -z "$conf_file" ] && [ -f "/etc/named.conf" ] && conf_file="/etc/named.conf"
                                conf_dir=`echo "$conf_file" | awk -F'/' '{ OFS="/"; $NF=""; print $0 }'`

                        }
                        [ -n "$conf_dir" -a -d "$conf_dir" ] && ls -dl "$conf_dir"/* > ./named/instances/$named_inst_counter/named-perm.txt
                        [ ! -f "./named/instances/$named_inst_counter/named-perm.txt" ] && touch ./named/instances/$named_inst_counter/named-perm.txt

                        echo "[+++++] Looking for configuration file in: $conf_file"
                        cat "$conf_file" > ./named/instances/$named_inst_counter/named.conf
                        echo "$conf_file" > ./named/instances/$named_inst_counter/named.conf-path.txt


                        [ -n "$conf_file" -a -f "$conf_file" ] && {

                                additional_conf_includes=`awk '$1 ~ /^([[:blank:]]|[[:space:]])*include([[:blank:]]|[[:space:]])*/ { print $2 }' "$conf_file" | sed 's/\"//g ; s/\;//g'`
                                for each_add_conf_include in ${additional_conf_includes}; do

					mkdir -p ./named/instances/$named_inst_counter/includes/ 
					each_add_conf_include_2=`echo "$each_add_conf_include" | sed 's/[/]/\_/g'`
				        cp "$each_add_conf_include" ./named/instances/$named_inst_counter/includes/"$each_add_conf_include_2"

                                        temp_dir=`awk '$1 ~ /^([[:blank:]]|[[:space:]])*(directory|managed-keys-directory)/ { print $2 }' "$each_add_conf_include" | sed 's/\"//g ; s/\;//g'`
                                        temp_dirs=`echo "$temp_dir"; echo "$temp_dirs"`
                                done

                                additional_conf_dirs=`awk '$1 ~ /^([[:blank:]]|[[:space:]])*(directory|managed-keys-directory)/ { print $2 }' "$conf_file" | sed 's/\"//g ; s/\;//g'`
                                additional_conf_dirs=`echo "$additional_conf_dirs $temp_dirs" | sed 's/ /\n/g' | sort -u`
                                for each_add_conf_dir in ${additional_conf_dirs}; do

                                        ls -ld "$each_add_conf_dir/"* >> ./named/instances/$named_inst_counter/named-perm.txt 2>>./not-found.txt
                                done
                        }

                        named_bin=`echo "$named_line" | awk '{ print $11 }' | sed 's/[ \t]\{0,\}$//g'`
                        [ -z "$named_bin" ] && named_bin="not_named_found"
                        if [ ! -f "$named_bin" ]; then

                                conf_root_path=`echo "$conf_file" | xargs dirname | xargs dirname`
                                named_bin2="$conf_root_path/sbin/named"

                                if [ -f "$named_bin2" ]; then

                                        named_bin="$named_bin2"
                                        named_version=`$named_bin -v | egrep BIND`
                                else

                                        named_bin="Bin not detected"
                                        named_version="Version not detected"
                                fi
                        else

                                named_version=`$named_bin -v | egrep BIND`
                        fi
                        echo "$named_bin" > ./named/instances/$named_inst_counter/named-bin.txt
                        echo "$named_version" > ./named/instances/$named_inst_counter/named-version.txt
                fi
        done

IFS="$IFS_bkp"
}

collect_named


fi


backup () {

  [ $# -ne 1 ] && return 1

  [ -z "$AWK" ] && {
    AWK=`which awk`
    [ -z "$AWK" ] && return 1
  }

  timestamp=`date +%Y%m%d%H%M%S`
  file_prefix=$1
  backup_dir=/var/security/

  [ ! -d "$backup_dir" ] && mkdir $backup_dir

  cp $file_prefix* $backup_dir && chmod 400 $backup_dir/$file_prefix*

  to_be_deleted=`ls $backup_dir | awk -v num=$BACKUP_VALIDATION 'function bubble_sort(arr, size) {

    for (__i=size-1; __i >= 1; __i--)
    {
      for (__j=1; __j < __i; __j++)
      {
        if (arr[__i] < arr[__j])
        {
          aux = arr[__i]
          arr[__i] = arr[__j]
          arr[j] = aux
        }
      }
    }

  }

  BEGIN {
    INDEX=0
    LIMIT=num
  }

  {
    split($0,fields,".")
    for (i in fields)
    {
      if (match(fields[i],/^[0-9]+$/))
      {
        DATA[INDEX++] = fields[i]
      }
    }
  }

  END {

     for(i in DATA) size++
     bubble_sort(DATA,size)

     if (size > LIMIT)
     {
       for (i=0; i<(size-LIMIT); i++)
       {
          print "*" DATA[i] "*"
       }
     }
  }'`
  [ -n "$to_be_deleted" ] && {
    for d in $to_be_deleted; do
      rm -rf $backup_dir/$d
    done
  }

}


[ -f "/var/security/backup/.prid" ] && {

        cat /var/security/backup/.prid > .prid
}

pwd | grep '' > /dev/null
if [ $? = 0 ]; then
    find ./ \( -size +10000 -o -name "*.[cC][rR][tT]" -o -name "*.[pP][eE][mM]" -o -name "*.[kK][eE][yY]" \) -exec ls -la '{}' \; > ./deleted.txt
    find ./ \( -size +10000 -o -name "*.[cC][rR][tT]" -o -name "*.[pP][eE][mM]" -o -name "*.[kK][eE][yY]" \) -exec /bin/rm -f '{}' \;
fi
cd ..
dateg=`date +%Y%m%d%H%M%S`
old_timestamp=`date +%y%m%d`
file_prefix="$maq.$dateg.tar"
tar cf $file_prefix $maq
bzip2 $file_prefix 2> /dev/null
gzip $file_prefix 2> /dev/null

if [ "$BACKUP" != "no"  ]; then

	backup "$file_prefix"
fi

filename=`ls ${file_prefix}* | sed "s/${dateg}/${old_timestamp}/"`
mv ${file_prefix}* $cur_dir/$filename


cd $cur_dir

if [ "$REMOVE_DIR" = yes -o ! -n "$REMOVE_DIR" ]; then
	[ "`pwd`" != "$DIR" ] && { 
  		cd $cur_dir
  		rm -rf $DIR 
	}
fi

echo "End of script."
