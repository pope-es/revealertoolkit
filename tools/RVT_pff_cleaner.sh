#!/bin/bash

# Pope> The power of shell, oh yeah!


# THIS IS VERY IMPORTANT !!!!!!!!! THIS IS VERY IMPORTANT !!!!!!!!!
IFS="
"
# END OF VERY IMPORTANT THING ;-)

RVT_moduleName="RVT_pff_cleaner.sh (external tool)"
RVT_moduleVersion="0.1" # por decir algo

target="$1"

echo "!!!!!!!!!! WARNING, first parameter should be an ABSOLUTE PATH !!!!!!!!!!!!"
echo "Parsing PFF output in path: $target"

for mensaje in $( find "$target" -type d -regex ".*Message[0-9][0-9][0-9][0-9][0-9]" ); do # this DOESN'T MATCH contacts, meetings, etc.
        
        cd "$mensaje"
        
        if [ ! -f RVT_metadata ]; then # This allows me to skip already parsed Messages.
                # Coger los To:
                total_to=""
                for address in $( grep  -B5 "^Recipient type:..To" Recipients.txt 2>/dev/null | grep "^Email address:" | sed 's/.*:..//g' ); do
                        displayname=$( grep  -B5 "^Recipient type:..To" Recipients.txt 2>/dev/null | grep -B4 "^Email address:..$address" | grep "^Display name:" | sed 's/.*:..//g' )
#                       total_to="${total_to}$displayname ($address); "
                        total_to="${total_to}$displayname; "
                done
                total_to=$( echo $total_to | sed 's/\(.*\), $/\1/g' )
                # Coger los Cc:
                total_cc=""
                for address in $( grep  -B5 "^Recipient type:..CC" Recipients.txt 2>/dev/null | grep "^Email address:" | sed 's/.*:..//g' ); do
                        displayname=$( grep  -B5 "^Recipient type:..CC" Recipients.txt 2>/dev/null | grep -B4 "^Email address:..$address" | grep "^Display name:" | sed 's/.*:..//g' )
#                       total_cc="${total_cc}$displayname ($address); "
                        total_cc="${total_cc}$displayname; "
                done
                total_cc=$( echo $total_cc | sed 's/\(.*\), $/\1/g' )
                # Coger los Bcc:
                total_bcc=""
                for address in $( grep  -B5 "^Recipient type:..BCC" Recipients.txt 2>/dev/null | grep "^Email address:" | sed 's/.*:..//g' ); do
                        displayname=$( grep  -B5 "^Recipient type:..BCC" Recipients.txt 2>/dev/null | grep -B4 "^Email address:..$address" | grep "^Display name:" | sed 's/.*:..//g' )
#                       total_bcc="${total_bcc}$displayname ($address); "
                        total_bcc="${total_bcc}$displayname; "
                done
                total_bcc=$( echo $total_bcc | sed 's/\(.*\); $/\1/g' )
                
                if [ -f OutlookHeaders.txt ]; then
                        subject=$( grep -h "^Subject:" OutlookHeaders.txt | cut -c12- )
                        date=$( grep -h "^Client submit time:" OutlookHeaders.txt | cut -c22- )
                        from_name=$( grep -h "^Sender name:" OutlookHeaders.txt | cut -c16- )
                        from_addr=$( grep -h "^Sender email address:" OutlookHeaders.txt | cut -c24- )          
                        notes=""
                        grep -E "^Flags.*Has attachments" OutlookHeaders.txt > /dev/null && notes="Has attachments; $notes"
                fi
                echo -e "# BEGIN RVT METADATA\n# Source file: $mensaje\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n#\n# From:    $from_name ($from_addr)\n# Date:    $date\n# Subject: $subject\n# To:      $total_to\n# Cc:      $total_cc\n# Bcc:     $total_bcc\n# Notes:   $notes\n#\n######### Section: OutlookHeaders.txt ########################################\n" > RVT_metadata
                if [ -f OutlookHeaders.txt ]; then cat OutlookHeaders.txt >> RVT_metadata; fi
                echo -e "######### End of section #####################################################\n\n" >> RVT_metadata
                echo "######### Section: InternetHeaders.txt #######################################" >> RVT_metadata
                if [ -f InternetHeaders.txt ]; then cat OutlookHeaders.txt >> RVT_metadata; fi
                echo -e "######### End of section #####################################################\n\n" >> RVT_metadata
                echo "######### Section: Recipients.txt ############################################" >> RVT_metadata
                if [ -f Recipients.txt ]; then cat OutlookHeaders.txt >> RVT_metadata; fi
                echo -e "######### End of section #####################################################\n\n" >> RVT_metadata
                echo "######### Section: ItemValues.txt ############################################" >> RVT_metadata
                if [ -f ItemValues.txt ]; then cat OutlookHeaders.txt >> RVT_metadata; fi
                echo -e "######### End of section #####################################################\n\n" >> RVT_metadata
                echo "######### Section: ConversationIndex.txt ############################################" >> RVT_metadata
                if [ -f ConversationIndex.txt ]; then cat OutlookHeaders.txt >> RVT_metadata; fi
                echo -e "######### End of section #####################################################\n\n# END RVT METADATA\n" >> RVT_metadata

                echo -e "<!--#$from_name ($from_addr)#$date#$subject#$total_to#$total_cc#$total_bcc#$notes#-->\n<HTML>\n<HEAD>\n<TITLE>$subject</TITLE>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n</HEAD>\n<BODY>\n<TABLE border=1 rules=none frame=box>\n<tr><td><b>From:</b></td><td>$from_name ($from_addr)</td></tr>\n<tr><td><b>Date:</b></td><td>$date</td></tr>\n<tr><td><b>Subject:</b></td><td>$subject</td></tr>\n<tr><td><b>To:</b></td><td>$total_to</td></tr>\n<tr><td><b>Cc:</b></td><td>$total_cc</td></tr>\n<tr><td><b>Bcc:</b></td><td>$total_bcc</td></tr>" > FullMessage.html
        
                ## AQUI LOS ADJUNTOS... aquí unos amigos.
                if [ -d Attachments ]; then
                        for attach in Attachments/*; do
                                echo "<tr><td><b>Attachment:</b></td><td><a href=\"$attach\">$( basename "$attach" )</a></td></tr>" >> FullMessage.html
                        done
                fi
                echo "</TABLE></HTML>" >> FullMessage.html
                if [ -f Message.txt ]; then
                        txt2html Message.txt >> FullMessage.html
                elif [ -f Message.html ]; then
                        cat Message.html >> FullMessage.html
                elif [ -f Message.rtf ]; then
                        unrtf Message.rtf >> FullMessage.html 2>/dev/null
                fi
        
                rm ItemValues.txt OutlookHeaders.txt InternetHeaders.txt Recipients.txt ConversationIndex.txt Message.* 2>/dev/null
        fi
        cd - >/dev/null 2>&1
done

echo "Cleaning additional items..." # WARNING this deletes files, like contact.txt, not parsed.

find $target -name ItemValues.txt -exec rm '{}' \;
# find $target -name Contact.txt -exec rm '{}' \;
echo "Done."
echo "WARNING, you should manually UPDATE allocfiles !!!"


# ESTA VERSIÓN DEL BUCLE TRABAJA SOBRE TODOS LOS HEADERS
# 
# for mensaje in $( find . -type d -regex ".*/Message[0-9]*" ); do
# 
#       cd "$mensaje"
#       
#       # Coger los To:
#       total_to=""
#       for address in $( grep  -B5 "^Recipient type:..To" Recipients.txt | grep "^Email address:" | sed 's/.*:..//g' ); do
#               displayname=$( grep  -B5 "^Recipient type:..To" Recipients.txt | grep -B4 "^Email address:.$address" | grep "^Display name:" | sed 's/.*:..//g' )
#               total_to="${total_to}$displayname ($address), "
#       done
#       total_to=$( echo $total_to | sed 's/\(.*\), $/\1/g' )
#       # Coger los Cc:
#       total_cc=""
#       for address in $( grep  -B5 "^Recipient type:..CC" Recipients.txt | grep "^Email address:" | sed 's/.*:..//g' ); do
#               displayname=$( grep  -B5 "^Recipient type:..CC" Recipients.txt | grep -B4 "^Email address:.$address" | grep "^Display name:" | sed 's/.*:..//g' )
#               total_cc="${total_cc}$displayname ($address), "
#       done
#       total_cc=$( echo $total_cc | sed 's/\(.*\), $/\1/g' )
#       # Coger los Bcc:
#       total_bcc=""
#       for address in $( grep  -B5 "^Recipient type:..BCC" Recipients.txt | grep "^Email address:" | sed 's/.*:..//g' ); do
#               displayname=$( grep  -B5 "^Recipient type:..BCC" Recipients.txt | grep -B4 "^Email address:.$address" | grep "^Display name:" | sed 's/.*:..//g' )
#               total_bcc="${total_bcc}$displayname ($address), "
#       done
#       total_bcc=$( echo $total_bcc | sed 's/\(.*\), $/\1/g' )
#       
#       # SUBJECT
#       subject=$( grep -h "^Subject" *Headers.txt | head -n 1 | sed 's/Subject:.//g' | ncd-decode_rfc2047.pl | tr -d  '\011' )
#       
#       # DATE
#       date=$( grep -h -e "^Date" -e "^Client submit time" *Headers.txt | head -n 1 | cut -d: -f2- | cut -c2- | tr -d  '\011' )
#       
#       # FROM
#       from=$( grep -h "^From" *Headers.txt | head -n 1 | cut -c7- )
#       
#       echo "###########################"
#       echo "$mensaje"
#       echo "From: $from"
#       echo "Date: $date"
#       echo "Subj: $subject"
#       echo "To:   $total_to"
# #     echo "Cc:   $total_cc"
# #     echo "Bcc:  $total_bcc"
#       
#       cd - >/dev/null 2>&1
# 
# done