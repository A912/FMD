  function GetVnSharingInfoFromURL: Byte;
  var
    s: String;
    isExtractSummary: Boolean = True;
    isExtractGenres: Boolean = False;
    i, j: Cardinal;
  begin
    mangaInfo.url := FillMangaSiteHost(VNSHARING_ID, URL) + '&confirm=yes';
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
    mangaInfo.website := WebsiteRoots[VNSHARING_ID, 0];
    // using parser (cover link, summary, chapter name and link)
    if parse.Count = 0 then
      Exit;
    for i := 0 to parse.Count - 1 do
    begin
      // get manga title
      if (mangaInfo.title = '') and
        (Pos('name="title"', parse.Strings[i]) > 0) then
        mangaInfo.title := TrimLeft(TrimRight(GetString(parse.Strings[i],
          '"Truyện ', ' | Đọc online')));

      // get cover
      if (GetTagName(parse.Strings[i]) = 'img') and
        (Pos('img width="190px" height="250px"', parse.Strings[i]) > 0) then
        mangaInfo.coverLink := CorrectURL(GetAttributeValue(
          GetTagAttribute(parse.Strings[i], 'src=')));

      // get summary
      if (Pos('Sơ lược:', parse.Strings[i]) <> 0) and
        (isExtractSummary) then
      begin
        j := i + 4;
        while (j < parse.Count) and (Pos('</p>', parse.Strings[j]) = 0) do
        begin
          s := parse.Strings[j];
          if s[1] <> '<' then
          begin
            parse.Strings[j] := HTMLEntitiesFilter(StringFilter(parse.Strings[j]));
            parse.Strings[j] := StringReplace(parse.Strings[j], #10, '\n', [rfReplaceAll]);
            parse.Strings[j] := StringReplace(parse.Strings[j], #13, '\r', [rfReplaceAll]);
            mangaInfo.summary := parse.Strings[j];
          end;
          Inc(j);
        end;
        isExtractSummary := False;
      end;

      // get chapter name and links
      if (i + 1 < parse.Count) and
        (GetTagName(parse.Strings[i]) = 'a') and
        (Pos('/Truyen/', parse.Strings[i]) > 0) and
        (Pos('title="Đọc', parse.Strings[i]) > 0) then
      begin
        Inc(mangaInfo.numChapter);
        mangaInfo.chapterLinks.Add(
          EncodeUrl(GetAttributeValue(GetTagAttribute(parse.Strings[i], 'href='))));
        parse.Strings[i + 1] := RemoveSymbols(TrimLeft(TrimRight(parse.Strings[i + 1])));
        mangaInfo.chapterName.Add(StringFilter(HTMLEntitiesFilter(parse.Strings[i + 1])));
      end;

      // get authors
      if (i + 4 < parse.Count) and (Pos('Tác giả:', parse.Strings[i]) <> 0) then
        mangaInfo.authors := TrimLeft(parse.Strings[i + 4]);

      // get artists
      if (i + 4 < parse.Count) and (Pos('Họa sỹ:', parse.Strings[i]) <> 0) then
        mangaInfo.artists := TrimLeft(parse.Strings[i + 4]);

      // get genres
      if (Pos('Thể loại:', parse.Strings[i]) <> 0) then
      begin
        isExtractGenres := True;
        mangaInfo.genres := '';
      end;

      if isExtractGenres then
      begin
        if (i + 1 < parse.Count) and (Pos('"/TheLoai/', parse.Strings[i]) > 0) then
          mangaInfo.genres := mangaInfo.genres +
            (TrimLeft(TrimRight(parse.Strings[i + 1])) + ', ');
        if Pos('</p>', parse.Strings[i]) <> 0 then
          isExtractGenres := False;
      end;

      // get status
      if (i + 2 < parse.Count) and (Pos('Tình trạng:', parse.Strings[i]) <> 0) then
      begin
        if Pos('Đang tiến hành', parse.Strings[i + 2]) <> 0 then
          mangaInfo.status := '1'   // ongoing
        else
          mangaInfo.status := '0';  // completed
      end;
    end;

    if (mangaInfo.status = '1') and (mangainfo.ChapterName.Count > 0) then
    begin
      Dec(mangaInfo.numChapter);
      mangainfo.ChapterName.Delete(mangainfo.ChapterName.Count - 1);
      mangainfo.ChapterLinks.Delete(mangainfo.ChapterLinks.Count - 1);
    end;
    // Since chapter name and link are inverted, we need to invert them
    if mangainfo.ChapterLinks.Count > 1 then
    begin
      i := 0;
      j := mangainfo.ChapterLinks.Count - 1;
      while (i < j) do
      begin
        mangainfo.ChapterName.Exchange(i, j);
        mangainfo.chapterLinks.Exchange(i, j);
        Inc(i);
        Dec(j);
      end;
    end;
    Result := NO_ERROR;
  end;
