cd input
for file in $(ls); do awk 'NF' $file > tmp; mv tmp $file; done
for file in $(ls); do echo -n "$file\$" >> tmp; while read line; do echo -n "$line " >> tmp; done<$file; mv tmp $file; echo "" >> $file; done
