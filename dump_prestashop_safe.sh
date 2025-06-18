#!/bin/bash

# Charger les variables d'environnement
set -o allexport
source .env
set +o allexport

# Vérification des variables nécessaires
if [[ -z "$DB_HOST" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_NAME" ]]; then
  echo "Les variables DB_HOST, DB_USER, DB_PASSWORD, DB_NAME sont requises."
  exit 1
fi

# Fichier SQL temporaire
DUMP_FILE="prestashop_clean_export.sql"

# Tables à exclure (clients, commandes, paiements)
EXCLUDE_TABLES=(
  ps_customer
  ps_address
  ps_orders
  ps_order_detail
  ps_order_history
  ps_order_invoice
  ps_order_payment
  ps_module --where="name NOT LIKE 'ps_%payment%'"
)

# Construction de la commande mysqldump
EXCLUDE_CLAUSES=""
for table in "${EXCLUDE_TABLES[@]}"; do
  if [[ "$table" == *--where=* ]]; then
    table_name=$(echo "$table" | cut -d' ' -f1)
    where_clause=$(echo "$table" | cut -d' ' -f2-)
    EXCLUDE_CLAUSES+=" --ignore-table=${DB_NAME}.${table_name}"
  else
    EXCLUDE_CLAUSES+=" --ignore-table=${DB_NAME}.${table}"
  fi
done

echo "Exporting"

# Dump sans les tables exclues
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" $DB_NAME $EXCLUDE_CLAUSES > "$DUMP_FILE"

# Création de l'utilisateur administrateur (ajout SQL à la fin du fichier)
echo "Adding admin user"

ADMIN_PASSWORD_HASH=$(php -r "echo password_hash('${USERPASSWORD}', PASSWORD_DEFAULT);")

cat <<EOF >> "$DUMP_FILE"

-- Adding admin user
INSERT INTO ps_employee (id_profile, id_lang, lastname, firstname, email, passwd, active, id_shop)
VALUES (1, 1, 'Dev_admin', 'Developper', '${USEREEMAIL}', '${ADMIN_PASSWORD_HASH}', 1, 1);

EOF

echo "Export done : $DUMP_FILE"
