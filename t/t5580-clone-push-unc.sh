#!/bin/sh

test_description='various Windows-only path tests'
. ./test-lib.sh

if test_have_prereq CYGWIN
then
	alias winpwd='cygpath -aw .'
elif test_have_prereq MINGW
then
	alias winpwd=pwd
else
	skip_all='skipping Windows-only path tests'
	test_done
fi

UNCPATH="$(winpwd)"
case "$UNCPATH" in
[A-Z]:*)
	WITHOUTDRIVE="${UNCPATH#?:}"
	# Use administrative share e.g. \\localhost\C$\git-sdk-64\usr\src\git
	# (we use forward slashes here because MSYS2 and Git accept them, and
	# they are easier on the eyes)
	UNCPATH="//localhost/${UNCPATH%%:*}\$$WITHOUTDRIVE"
	;;
*)
	skip_all='skipping UNC path tests, cannot determine current path as UNC'
	test_done
	;;
esac

test_expect_success 'clone into absolute path lacking a drive prefix' '
	USINGBACKSLASHES="$(echo "$WITHOUTDRIVE"/without-drive-prefix |
		tr / \\\\)" &&
	git clone . "$USINGBACKSLASHES" &&
	test -f without-drive-prefix/.git/HEAD
'

test -d "$UNCPATH" || {
	skip_all='could not access administrative share; skipping'
	test_done
}

test_expect_success setup '
	test_commit initial
'

test_expect_success clone '
	git clone "file://$UNCPATH" clone
'

test_expect_success push '
	(
		cd clone &&
		git checkout -b to-push &&
		test_commit to-push &&
		git push origin HEAD
	) &&
	rev="$(git -C clone rev-parse --verify refs/heads/to-push)" &&
	test "$rev" = "$(git rev-parse --verify refs/heads/to-push)"
'

test_expect_success MINGW 'remote nick cannot contain backslashes' '
	BACKSLASHED="$(winpwd | tr / \\\\)" &&
	git ls-remote "$BACKSLASHED" >out 2>err &&
	test_i18ngrep ! "unable to access" err
'

test_done
