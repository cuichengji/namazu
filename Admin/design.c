#include <libnmz.h>

int
main()
{
    // $B%/%(%j!<$OC1$J$kJ8;zNs(B ($B$G$$$$$N(B?)
    // nmz_idxset_search $B$NCf$G%Q!<%:$9$k$N$H(B
    // $B30$G%Q!<%:$7$FEO$9$N$H$I$A$i$,$$$$$N$@$m$&(B?
    // $B30$G%Q!<%:$9$k$J$i(B 
    //   nmz_query *q = nmz_query_new("foo and bar");
    // $B$H$$$C$?46$8$+$J(B?
    char *query = "foo and bar";

    // $B@_Dj%U%!%$%k$rFI$_9~$`(B
    nmz_config *conf = nmz_config_new("/foo/bar/namazurc");

    // $B%$%s%G%C%/%9$N=89g$r07$&%*%V%8%'%/%H$r@8@.$9$k(B
    nmz_idxset *foo = nmz_idxset_new(conf);

    // $B8!:w7k2LMQ$N%*%V%8%'%/%H(B
    nmz_doclist *result = nmz_doclist_new(conf);

    // $B8!:wBP>]$N%$%s%G%C%/%9$rEPO?$9$k(B ($B=EJ#$O=|5n$5$l$k(B)
    nmz_idxset_insert(foo, "/foo/bar/Namazu/idx1");
    nmz_idxset_insert(foo, "/foo/bar/Namazu/idx2");
    nmz_idxset_insert(foo, "/foo/bar/Namazu/idx3");
    
    // $B8!:w7k2L(B ($B%R%C%H$7$?J8=q$N%j%9%H(B) $B$rF@$k(B
    result = nmz_idxset_search(foo, query);
    // $BF1$8%$%s%G%C%/%9=89g$KBP$7$FJL$N%/%(%j!<$G8!:w$G$-$k(B
    // result2 = nmz_idxset_search(foo, query2);

    // $B8!:w7k2L$r%=!<%H$9$k(B ($B9_=g(B)
    nmz_doclist_sort(result, NMZ_SORT_BY_SCORE);

    // $BJ8=q$N%j%9%H$r5U=g$K$9$k(B ($B%=!<%H$r>:=g$K$9$k(B)
    // nmz_doclist_reverse(result);

    for (i = 0; i < result->len; i++) {
	// $BJ8=q$N%j%9%H$+$i(B n$BHVL\$NJ8=q$X$N%]%$%s%?$rF@$k(B
	nmz_doc *doc = nmz_doclist_nth_doc(result, i);

	// $B8!:w7k2LI=<(MQ$NMWLs$r(B HTML$B7A<0$G<h$j=P$9(B (NMZ.result $B$K1~$8$F(B)
	char *summary  = nmz_idxset_get_html_summary(foo, doc, i);

	// plain text $B$N7A<0$G<h$j=P$9$3$H$b2DG=(B
	// char *summary  = nmz_idxset_get_plain_summary(foo, doc, i);

	// $B8!:w7k2L$rI=<($9$k(B
	printf("%s\n", summary);
    }

    // $B8eJR$E$1(B
    // nmz_idxset_destroy(foo);
    // nmz_doclist_destroy(result);

    return 0;
}

