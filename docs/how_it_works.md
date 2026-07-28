Backend:
1. SQLManager
2. IndexingService
3. Ai Pipeline using InferenceRepo
4. Face Cluster Service
5. QueryService

Frontend:
1. Photomanager 
2. PermissionManager
3. StorageManager

1. Make a folder structure for separating frontend and backend
2. Fix providers
3. Skip videos in indexing service
4. Make the FaceClusterService clean
5. In IndexingService multiple responsibilities are carried fix it 


- App
- App Startup 
    - Check Permission using PermissionManager
    - Check storage using StorageManager
    - Sync photos to sql using SQLManager
    - Starts IndexingService
- App router
    - Shows onboarding flow if not done
    - Shows image gallery
    - Shows progress strip of image indexing
- Search bar
    - Uses query service
- IndexingService
    - Get unindexedData from SQLManager
    - Cler prev queue
    - registerBackgroundTask (need to see more about this)
    - Check if thermal state o r battery is low that throttle
    - Get image from photo manager by id and decode its rgb pixels
    - Run the PipelineService
    - Mark indexed
    - When all assets are done run Face Cluster Service
- Face Cluster Service
    - In people section show groups of similar faces
    - Need to know more about this
- QueryService
    - Extracts 3 things from the query: emotion, date/time, cluster
    -  if found then its removed from normal query 
    - Their standard format is used like EmotionNet enum, date format, clusterId
    - And then where filters are made for above 3 things along with normal vector search
