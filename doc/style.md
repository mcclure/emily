ML coding standards for Emily project

- Variable and package names are camelCased (contrary to normal ML standards). I could probably be talked into changing this.
- Tabs should be 4 spaces, no tab characters should appear in source. To ensure I don't accidentally mix in tabs, I install [the Checkfiles Extension](http://mercurial.selenic.com/wiki/CheckFilesExtension) for Mercurial and then I add this to my `.hg/hgrc`:

        [hooks]
        pretxncommit.checkfiles=hg checkfiles
        [checkfiles]
        checked_exts = .ml .em .py .pl
