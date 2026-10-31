require ["fileinto"];

# En-tête ajouté par Rspamd quand le score dépasse le seuil "add header"
if header :contains "X-Spam-Status" "Yes" {
  fileinto "Junk";
  stop;
}
