  function GetEGScansInfoFromURL: Byte;
  var
    s: String;
    isExtractChapter: Boolean = False;
    i: Cardinal;
  begin
    mangaInfo.website := WebsiteRoots[EGSCANS_ID, 0];
    mangaInfo.url :=FillMangaSiteHost(EGSCANS_ID, '/' + URL);
    if not GetPage(TObject(Source), mangaInfo.url, Reconnect) then
    begin
      Result := NET_PROBLEM;
      Source.Free;
      Exit;
    end;

    // parsing the HTML source
    parse.Clear;
    Parser := THTMLParser.Create(PChar(Source.Text));
    Parser.OnFoundTag := OnTag;
    Parser.OnFoundText := OnText;
    Parser.Exec;

    Parser.Free;
    Source.Free;

    mangaInfo.status := '1';
    mangaInfo.coverLink := '';
    mangaInfo.summary := '';
    mangaInfo.authors := '';
    mangaInfo.artists := '';
    mangaInfo.genres := '';

    // using parser (cover link, summary, chapter name and link)
    if parse.Count = 0 then
      Exit;
    for i := 0 to parse.Count - 1 do
    begin
      // get chapter name and links
      if (not isExtractChapter) and
        (Pos('<span>', parse.Strings[i]) > 0) and
        (Pos('Chapter', parse.Strings[i + 1]) > 0) then
        isExtractChapter := True;

      if (isExtractChapter) and
        (Pos('</span>', parse.Strings[i]) > 0) then
        isExtractChapter := False;

      // get manga name
      if (mangaInfo.title = '') and (Pos('content="Read ', parse.Strings[i]) > 0) then
        mangaInfo.title := GetString(parse.Strings[i], '~!@content="Read ',
          ' Manga Online"');

   { if (isExtractChapter) AND (Pos('</select>', parse.Strings[i])>0) then
      break; }

      if (isExtractChapter) and
        (Pos('<option value="', parse.Strings[i]) > 0) then
      begin
        Inc(mangaInfo.numChapter);
        s := '/' + URL + '/' + StringReplace(GetAttributeValue(
          GetTagAttribute(parse.Strings[i], 'value=')), WebsiteRoots[EGSCANS_ID, 1], '', []);
        mangaInfo.chapterLinks.Add(s);
        s := RemoveSymbols(TrimLeft(TrimRight(parse.Strings[i + 1])));
        mangaInfo.chapterName.Add(StringFilter(StringFilter(HTMLEntitiesFilter(s))));
      end;
    end;

    Result := NO_ERROR;
  end;
