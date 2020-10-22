#/bin/bash
cd "$(dirname "$0")"

# Each table has a given amount of rows, which we will use to clean wrong
# entries. Only entries that has these amount of columns will be kept.
PARTY_COLUMNS=17
FILING_COLUMNS=63
FILING_ANNUAL_REPORT_COLUMNS=7

FOLDER_DIR=../data

# Our tables, based in our filenames from the unzipped export
declare -a tables=('PARTY' 'FILING' 'FILING_ANNUAL_REPORT' )

for table in "${tables[@]}"
do
  #We need to dynamically create our variable
  declare current_column=${table}_COLUMNS
  echo "Current table column: $current_column"
  # We need to eval our variable to obtain its value
  quotes_per_row=$((${current_column}*2))
  echo "Total columns in $table $(($quotes_per_row/2))"
  # We then keep the line numbers of the ones that DO NOT satisfy our condition
  echo "Finding wrong entries for $table.csv, this might take a while."
  awk -F "\"" '{print NF-1}' ${FOLDER_DIR}/${table}.csv | grep -vn $quotes_per_row \
    > ${FOLDER_DIR}/${table}_lines_to_cut.txt
  total_entries_in_table=$(wc -l < ${FOLDER_DIR}/${table}.csv)
  total_lines_to_cut=$(wc -l < ${FOLDER_DIR}/${table}_lines_to_cut.txt)
  echo "Found $total_lines_to_cut out of ${total_entries_in_table} wrong entries"
  # We need a final cleanup in our lines to cut file
  cut -d':' -f1 ${FOLDER_DIR}/${table}_lines_to_cut.txt > \
    ${FOLDER_DIR}/${table}_lines_to_delete.txt
  # We keep the column headers from our original file into the new file
  table_header=$(head -n 1 ${FOLDER_DIR}/${table}.csv)
  # We finally use these lines and remove them from our original file into a
  # tmp file we will use later
  awk 'NR==FNR{n[$1];next}!(FNR in n)' ${FOLDER_DIR}/${table}_lines_to_delete.txt ${FOLDER_DIR}/${table}.csv > ${FOLDER_DIR}/${table}.tmp.csv
  total_lines_in_cleaned_csv=$(wc -l < ${FOLDER_DIR}/${table}.tmp.csv)
  echo "Found $total_lines_in_cleaned_csv entries to be used"
  # We restore the original headers into a new file
  echo $table_header > ${FOLDER_DIR}/${table}.tmp.txt
  cat ${FOLDER_DIR}/${table}.tmp.txt ${FOLDER_DIR}/${table}.tmp.csv > ${FOLDER_DIR}/${table}_CLEANED.csv
  # Cleanup our line and tmp files
  rm ${FOLDER_DIR}/${table}*.txt
  rm ${FOLDER_DIR}/${table}*.tmp.*
done

