#!/bin/sh -e

__domain()
{
    registered='-'
    registrant='-'
    country='-'
    nserver='-'
    whois="$( whois "$1" || true )"

    if [ -n "$whois" ]
    then
        get_registered="$( echo "$whois" | sed -nr 's/^registered:\s+([0-9-]{10})\s.+/\1/p' )"

        if [ -n "$get_registered" ]
        then
            registered="$get_registered"
        fi

        get_registrant="$( echo "$whois" | sed -nr 's/^org\sid:\s+([a-z0-9]+)/\1/pI' | sed -e 's/\(.*\)/\L\1/' )"

        if [ -n "$get_registrant" ]
        then
            registrant="$get_registrant"
        fi

        get_country="$( echo "$whois" | sed -nr 's/^country:\s+([a-z]+)/\1/pI' | sed -e 's/\(.*\)/\L\1/' )"

        if [ -n "$get_country" ]
        then
            country="$get_country"
        fi
    fi

    get_nserver="$( dig +short soa "$1" | awk '{print $1}' | sed 's/\.$//' | sed -e 's/\(.*\)/\L\1/' )"

    if [ -n "$get_nserver" ]
    then
        if get_psl="$( echo "$get_nserver" | psl -b --print-reg-domain )"
        then
            nserver="$get_psl"
        else
            nserver="$get_nserver"
        fi
    fi

    echo "$1 $registered $registrant $country $nserver"
}

domains_in_zone="$( dig +noidnout ee axfr @zone.internet.ee \
    | grep -Po '^(.+\..+)(?=\.\s+[0-9]+\s+IN\s+NS\s+)' \
    | sort -u )"

if [ "$( echo "$domains_in_zone" | grep -Evc '^$' )" -lt 130000 ]
then
    echo 'borked zone transfer?' >&2
    exit 1
fi

add_domains="$( echo "$domains_in_zone" | comm -13 list - )"

remove_domains="$( echo "$domains_in_zone" | comm -13 - list )"

if [ -z "$add_domains" ] && [ -z "$remove_domains" ]
then
    exit 0
fi

if [ -n "$add_domains" ]
then
    echo "$add_domains" | while read -r l
    do
        echo "$l" >> list
        __domain "$l" >> info
    done

    sort -o list list
    sort -o info info

    added_count="$( echo "$add_domains" | grep -Evc '^$' )"
fi

if [ -n "$remove_domains" ]
then
    echo "$remove_domains" | while read -r l
    do
        sed -i "/^$l\$/d" list
        sed -i "/^$l\s/d" info
    done

    removed_count="$( echo "$remove_domains" | grep -Evc '^$' )"
fi

if [ -n "$added_count" ]
then
    printf '%s added' "$added_count"
fi

if [ -n "$removed_count" ]
then
    if [ -n "$added_count" ]
    then
        printf ', '
    fi

    printf '%s removed' "$removed_count"
fi

if [ -n "$added_count" ] || [ -n "$removed_count" ]
then
    printf '\n\n'
fi

if [ -n "$add_domains" ]
then
    printf '%s\n' "$( echo "$add_domains" | sed 's/^/+/' )"
fi

if [ -n "$remove_domains" ]
then
    printf '%s\n' "$( echo "$remove_domains" | sed 's/^/-/' )"
fi
