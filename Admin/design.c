#include <libnmz.h>

int
main()
{
    // クエリーは単なる文字列 (でいいの?)
    // nmz_idxset_search の中でパーズするのと
    // 外でパーズして渡すのとどちらがいいのだろう?
    // 外でパーズするなら 
    //   nmz_query *q = nmz_query_new("foo and bar");
    // といった感じかな?
    char *query = "foo and bar";

    // 設定ファイルを読み込む
    nmz_config *conf = nmz_config_new("/foo/bar/namazurc");

    // インデックスの集合を扱うオブジェクトを生成する
    nmz_idxset *foo = nmz_idxset_new(conf);

    // 検索結果用のオブジェクト
    nmz_doclist *result = nmz_doclist_new(conf);

    // 検索対象のインデックスを登録する (重複は除去される)
    nmz_idxset_insert(foo, "/foo/bar/Namazu/idx1");
    nmz_idxset_insert(foo, "/foo/bar/Namazu/idx2");
    nmz_idxset_insert(foo, "/foo/bar/Namazu/idx3");
    
    // 検索結果 (ヒットした文書のリスト) を得る
    result = nmz_idxset_search(foo, query);
    // 同じインデックス集合に対して別のクエリーで検索できる
    // result2 = nmz_idxset_search(foo, query2);

    // 検索結果をソートする (降順)
    nmz_doclist_sort(result, NMZ_SORT_BY_SCORE);

    // 文書のリストを逆順にする (ソートを昇順にする)
    // nmz_doclist_reverse(result);

    for (i = 0; i < result->len; i++) {
	// 文書のリストから n番目の文書へのポインタを得る
	nmz_doc *doc = nmz_doclist_nth_doc(result, i);

	// 検索結果表示用の要約を HTML形式で取り出す (NMZ.result に応じて)
	char *summary  = nmz_idxset_get_html_summary(foo, doc, i);

	// plain text の形式で取り出すことも可能
	// char *summary  = nmz_idxset_get_plain_summary(foo, doc, i);

	// 検索結果を表示する
	printf("%s\n", summary);
    }

    // 後片づけ
    // nmz_idxset_destroy(foo);
    // nmz_doclist_destroy(result);

    return 0;
}

