$UIResourceMgr = New-Object -ComObject UIResource.UIResourceMgr
$Cache = $UIResourceMgr.GetCacheInfo()
$CacheElements = $Cache.GetCacheElements()
foreach ($Element in $CacheElements){
        $Cache.DeleteCacheElement($Element.CacheElementID)
}
