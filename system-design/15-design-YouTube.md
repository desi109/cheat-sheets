# 15 - Design YouTube

In this chapter, you are asked to design YouTube. The solution to this question can be applied to other interview questions like designing a video sharing platform such as Netflix and Hulu. Figure 1 shows the YouTube homepage.

![YouTube Homepage](images/15-design-YouTube/figure1-youtube-homepage.png)

*Figure 1: YouTube Homepage*

YouTube looks simple: content creators upload videos and viewers click play. Is it really that simple? Not really. There are lots of complex technologies underneath the simplicity. Let us look at some impressive statistics, demographics, and fun facts of YouTube in 2020 [1] [2].

- **Total number of monthly active users:** 2 billion
- **Number of videos watched per day:** 5 billion
- **73% of US adults use YouTube**
- **50 million creators on YouTube**
- **YouTube's Ad revenue was $15.1 billion for the full year 2019, up 36% from 2018**
- **YouTube is responsible for 37% of all mobile internet traffic**
- **YouTube is available in 80 different languages**

From these statistics, we know YouTube is enormous, global and makes a lot of money.

## Step 1 - Understand the problem and establish design scope

As revealed in Figure 1, besides watching a video, you can do a lot more on YouTube. For example, comment, share, or like a video, save a video to playlists, subscribe to a channel, etc. It is impossible to design everything within a 45- or 60-minute interview. Thus, it is important to ask questions to narrow down the scope.

**Candidate:** What features are important?

**Interviewer:** Ability to upload a video and watch a video.

**Candidate:** What clients do we need to support?

**Interviewer:** Mobile apps, web browsers, and smart TV.

**Candidate:** How many daily active users do we have?

**Interviewer:** 5 million

**Candidate:** What is the average daily time spent on the product?

**Interviewer:** 30 minutes.

**Candidate:** Do we need to support international users?

**Interviewer:** Yes, a large percentage of users are international users.

**Candidate:** What are the supported video resolutions?

**Interviewer:** The system accepts most of the video resolutions and formats.

**Candidate:** Is encryption required?

**Interviewer:** Yes

**Candidate:** Any file size requirement for videos?

**Interviewer:** Our platform focuses on small and medium-sized videos. The maximum allowed video size is 1GB.

**Candidate:** Can we leverage some of the existing cloud infrastructures provided by Amazon, Google, or Microsoft?

**Interviewer:** That is a great question. Building everything from scratch is unrealistic for most companies, it is recommended to leverage some of the existing cloud services.

In the chapter, we focus on designing a video streaming service with the following features:

- Ability to upload videos fast
- Smooth video streaming
- Ability to change video quality
- Low infrastructure cost
- High availability, scalability, and reliability requirements
- Clients supported: mobile apps, web browser, and smart TV

## Back of the envelope estimation

The following estimations are based on many assumptions, so it is important to communicate with the interviewer to make sure she is on the same page.

- Assume the product has 5 million daily active users (DAU).
- Users watch 5 videos per day.
- 10% of users upload 1 video per day.
- Assume the average video size is 300 MB.

**Total daily storage space needed:** 5 million * 10% * 300 MB = 150TB

### CDN cost

When cloud CDN serves a video, you are charged for data transferred out of the CDN.

Let us use Amazon's CDN CloudFront for cost estimation (Figure 2) [3]. Assume 100% of traffic is served from the United States. The average cost per GB is $0.02. For simplicity, we only calculate the cost of video streaming.

5 million * 5 videos * 0.3GB * $0.02 = $150,000 per day.

From the rough cost estimation, we know serving videos from the CDN costs lots of money. Even though cloud providers are willing to lower the CDN costs significantly for big customers, the cost is still substantial. We will discuss ways to reduce CDN costs in deep dive.

![CloudFront Pricing](images/15-design-YouTube/figure2-cloudfront-pricing.png)

*Figure 2: CloudFront Pricing*

## Step 2 - Propose high-level design and get buy-in

As discussed previously, the interviewer recommended leveraging existing cloud services instead of building everything from scratch. CDN and blob storage are the cloud services we will leverage. Some readers might ask why not building everything by ourselves? Reasons are listed below:

1. System design interviews are not about building everything from scratch. Within the limited time frame, choosing the right technology to do a job right is more important than explaining how the technology works in detail. For instance, mentioning blob storage for storing source videos is enough for the interview. Talking about the detailed design for blob storage could be an overkill.

2. Building scalable blob storage or CDN is extremely complex and costly. Even large companies like Netflix or Facebook do not build everything themselves. Netflix leverages Amazon's cloud services [4], and Facebook uses Akamai's CDN [5].

At the high-level, the system comprises three components (Figure 3).

![High-Level System Architecture](images/15-design-YouTube/figure3-high-level-architecture.png)

*Figure 3: High-Level System Architecture*

- **Client:** You can watch YouTube on your computer, mobile phone, and smartTV.
- **CDN:** Videos are stored in CDN. When you press play, a video is streamed from the CDN.
- **API servers:** Everything else except video streaming goes through API servers. This includes feed recommendation, generating video upload URL, updating metadata database and cache, user signup, etc.

In the question/answer session, the interviewer showed interests in two flows:

1. Video uploading flow
2. Video streaming flow

We will explore the high-level design for each of them.

### Video uploading flow

Figure 4 shows the high-level design for the video uploading.

![Video Uploading Flow](images/15-design-YouTube/figure4-video-uploading-flow.png)

*Figure 4: Video Uploading Flow*

It consists of the following components:

- **User:** A user watches YouTube on devices such as a computer, mobile phone, or smart TV.
- **Load balancer:** A load balancer evenly distributes requests among API servers.
- **API servers:** All user requests go through API servers except video streaming.
- **Metadata DB:** Video metadata are stored in Metadata DB. It is sharded and replicated to meet performance and high availability requirements.
- **Metadata cache:** For better performance, video metadata and user objects are cached.
- **Original storage:** A blob storage system is used to store original videos. A quotation in Wikipedia regarding blob storage shows that: "A Binary Large Object (BLOB) is a collection of binary data stored as a single entity in a database management system" [6].
- **Transcoding servers:** Video transcoding is also called video encoding. It is the process of converting a video format to other formats (MPEG, HLS, etc), which provide the best video streams possible for different devices and bandwidth capabilities.
- **Transcoded storage:** It is a blob storage that stores transcoded video files.
- **CDN:** Videos are cached in CDN. When you click the play button, a video is streamed from the CDN.
- **Completion queue:** It is a message queue that stores information about video transcoding completion events.
- **Completion handler:** This consists of a list of workers that pull event data from the completion queue and update metadata cache and database.

Now that we understand each component individually, let us examine how the video uploading flow works. The flow is broken down into two processes running in parallel.

a. Upload the actual video.
b. Update video metadata. Metadata contains information about video URL, size, resolution, format, user info, etc.

#### Flow a: upload the actual video

![Upload Actual Video Flow](images/15-design-YouTube/figure5-upload-actual-video.png)

*Figure 5: Upload Actual Video Flow*

Figure 5 shows how to upload the actual video. The explanation is shown below:

1. Videos are uploaded to the original storage.
2. Transcoding servers fetch videos from the original storage and start transcoding.
3. Once transcoding is complete, the following two steps are executed in parallel:
   - 3a. Transcoded videos are sent to transcoded storage.
   - 3b. Transcoding completion events are queued in the completion queue.
   - 3a.1. Transcoded videos are distributed to CDN.
   - 3b.1. Completion handler contains a bunch of workers that continuously pull event data from the queue.
   - 3b.1.a. and 3b.1.b. Completion handler updates the metadata database and cache when video transcoding is complete.
4. API servers inform the client that the video is successfully uploaded and is ready for streaming.

#### Flow b: update the metadata

While a file is being uploaded to the original storage, the client in parallel sends a request to update the video metadata as shown in Figure 6. The request contains video metadata, including file name, size, format, etc. API servers update the metadata cache and database.

![Update Metadata Flow](images/15-design-YouTube/figure6-update-metadata.png)

*Figure 6: Update Metadata Flow*

### Video streaming flow

Whenever you watch a video on YouTube, it usually starts streaming immediately and you do not wait until the whole video is downloaded. Downloading means the whole video is copied to your device, while streaming means your device continuously receives video streams from remote source videos. When you watch streaming videos, your client loads a little bit of data at a time so you can watch videos immediately and continuously.

Before we discuss video streaming flow, let us look at an important concept: streaming protocol. This is a standardized way to control data transfer for video streaming. Popular streaming protocols are:

- **MPEG–DASH.** MPEG stands for "Moving Picture Experts Group" and DASH stands for "Dynamic Adaptive Streaming over HTTP".
- **Apple HLS.** HLS stands for "HTTP Live Streaming".
- **Microsoft Smooth Streaming.**
- **Adobe HTTP Dynamic Streaming (HDS).**

You do not need to fully understand or even remember those streaming protocol names as they are low-level details that require specific domain knowledge. The important thing here is to understand that different streaming protocols support different video encodings and playback players. When we design a video streaming service, we have to choose the right streaming protocol to support our use cases. To learn more about streaming protocols, here is an excellent article [7].

Videos are streamed from CDN directly. The edge server closest to you will deliver the video. Thus, there is very little latency. Figure 7 shows a high level of design for video streaming.

![Video Streaming Flow](images/15-design-YouTube/figure7-video-streaming-flow.png)

*Figure 7: Video Streaming Flow*

## Step 3 - Design deep dive

In the high-level design, the entire system is broken down in two parts: video uploading flow and video streaming flow. In this section, we will refine both flows with important optimizations and introduce error handling mechanisms.

### Video transcoding

When you record a video, the device (usually a phone or camera) gives the video file a certain format. If you want the video to be played smoothly on other devices, the video must be encoded into compatible bitrates and formats. Bitrate is the rate at which bits are processed over time. A higher bitrate generally means higher video quality. High bitrate streams need more processing power and fast internet speed.

Video transcoding is important for the following reasons:

1. Raw video consumes large amounts of storage space. An hour-long high definition video recorded at 60 frames per second can take up a few hundred GB of space.
2. Many devices and browsers only support certain types of video formats. Thus, it is important to encode a video to different formats for compatibility reasons.
3. To ensure users watch high-quality videos while maintaining smooth playback, it is a good idea to deliver higher resolution video to users who have high network bandwidth and lower resolution video to users who have low bandwidth.
4. Network conditions can change, especially on mobile devices. To ensure a video is played continuously, switching video quality automatically or manually based on network conditions is essential for smooth user experience.

Many types of encoding formats are available; however, most of them contain two parts:

- **Container:** This is like a basket that contains the video file, audio, and metadata. You can tell the container format by the file extension, such as .avi, .mov, or .mp4.
- **Codecs:** These are compression and decompression algorithms aim to reduce the video size while preserving the video quality. The most used video codecs are H.264, VP9, and HEVC.

### Directed acyclic graph (DAG) model

Transcoding a video is computationally expensive and time-consuming. Besides, different content creators may have different video processing requirements. For instance, some content creators require watermarks on top of their videos, some provide thumbnail images themselves, and some upload high definition videos, whereas others do not.

To support different video processing pipelines and maintain high parallelism, it is important to add some level of abstraction and let client programmers define what tasks to execute. For example, Facebook's streaming video engine uses a directed acyclic graph (DAG) programming model, which defines tasks in stages so they can be executed sequentially or parallelly [8]. In our design, we adopt a similar DAG model to achieve flexibility and parallelism. Figure 8 represents a DAG for video transcoding.

![DAG for Video Transcoding](images/15-design-YouTube/figure8-dag-video-transcoding.svg)

*Figure 8: DAG for Video Transcoding*

In Figure 8, the original video is split into video, audio, and metadata. Here are some of the tasks that can be applied on a video file:

- **Inspection:** Make sure videos have good quality and are not malformed.
- **Video encodings:** Videos are converted to support different resolutions, codec, bitrates, etc. Figure 9 shows an example of video encoded files.
- **Thumbnail.** Thumbnails can either be uploaded by a user or automatically generated by the system.
- **Watermark:** An image overlay on top of your video contains identifying information about your video.

![Video Encoded Files](images/15-design-YouTube/figure9-video-encoded-files.svg)

*Figure 9: Video Encoded Files*

### Video transcoding architecture

The proposed video transcoding architecture that leverages the cloud services, is shown in Figure 10.

![Video Transcoding Architecture](images/15-design-YouTube/figure10-video-transcoding-architecture.svg)

*Figure 10: Video Transcoding Architecture*

The architecture has six main components: preprocessor, DAG scheduler, resource manager, task workers, temporary storage, and encoded video as the output. Let us take a close look at each component.

#### Preprocessor

![Preprocessor](images/15-design-YouTube/figure11-preprocessor.svg)

*Figure 11: Preprocessor*

The preprocessor has 4 responsibilities:

1. **Video splitting.** Video stream is split or further split into smaller Group of Pictures (GOP) alignment. GOP is a group/chunk of frames arranged in a specific order. Each chunk is an independently playable unit, usually a few seconds in length.
2. Some old mobile devices or browsers might not support video splitting. Preprocessor split videos by GOP alignment for old clients.
3. **DAG generation.** The processor generates DAG based on configuration files client programmers write. Figure 12 is a simplified DAG representation which has 2 nodes and 1 edge:

![Simplified DAG Representation](images/15-design-YouTube/figure12-simplified-dag.svg)

*Figure 12: Simplified DAG Representation*

This DAG representation is generated from the two configuration files below (Figure 13):

![DAG Configuration Files](images/15-design-YouTube/figure13-dag-configuration.png)

*Figure 13: DAG Configuration Files (source: [9])*

4. **Cache data.** The preprocessor is a cache for segmented videos. For better reliability, the preprocessor stores GOPs and metadata in temporary storage. If video encoding fails, the system could use persisted data for retry operations.

#### DAG scheduler

![DAG Scheduler](images/15-design-YouTube/figure14-dag-scheduler.svg)

*Figure 14: DAG Scheduler*

The DAG scheduler splits a DAG graph into stages of tasks and puts them in the task queue in the resource manager. Figure 15 shows an example of how the DAG scheduler works.

![DAG Scheduler Example](images/15-design-YouTube/figure15-dag-scheduler-example.svg)

*Figure 15: DAG Scheduler Example*

As shown in Figure 15, the original video is split into three stages: Stage 1: video, audio, and metadata. The video file is further split into two tasks in stage 2: video encoding and thumbnail. The audio file requires audio encoding as part of the stage 2 tasks.

#### Resource manager

![Resource Manager](images/15-design-YouTube/figure16-resource-manager.svg)

*Figure 16: Resource Manager*

The resource manager is responsible for managing the efficiency of resource allocation. It contains 3 queues and a task scheduler as shown in Figure 17.

- **Task queue:** It is a priority queue that contains tasks to be executed.
- **Worker queue:** It is a priority queue that contains worker utilization info.
- **Running queue:** It contains info about the currently running tasks and workers running the tasks.
- **Task scheduler:** It picks the optimal task/worker, and instructs the chosen task worker to execute the job.

![Resource Manager Queues](images/15-design-YouTube/figure17-resource-manager-queues.svg)

*Figure 17: Resource Manager Queues*

The resource manager works as follows:

1. The task scheduler gets the highest priority task from the task queue.
2. The task scheduler gets the optimal task worker to run the task from the worker queue.
3. The task scheduler instructs the chosen task worker to run the task.
4. The task scheduler binds the task/worker info and puts it in the running queue.
5. The task scheduler removes the job from the running queue once the job is done.

#### Task workers

![Task Workers](images/15-design-YouTube/figure18-task-workers.svg)

*Figure 18: Task Workers*

Task workers run the tasks which are defined in the DAG. Different task workers may run different tasks as shown in Figure 19.

![Task Worker Types](images/15-design-YouTube/figure19-task-worker-types.svg)

*Figure 19: Task Worker Types*

#### Temporary storage

![Temporary Storage](images/15-design-YouTube/figure20-temporary-storage.svg)

*Figure 20: Temporary Storage*

Multiple storage systems are used here. The choice of storage system depends on factors like data type, data size, access frequency, data life span, etc. For instance, metadata is frequently accessed by workers, and the data size is usually small. Thus, caching metadata in memory is a good idea. For video or audio data, we put them in blob storage. Data in temporary storage is freed up once the corresponding video processing is complete.

#### Encoded video

![Encoded Video](images/15-design-YouTube/figure21-encoded-video.svg)

*Figure 21: Encoded Video*

Encoded video is the final output of the encoding pipeline. Here is an example of the output: funny_720p.mp4.

### System optimizations

At this point, you ought to have good understanding about the video uploading flow, video streaming flow and video transcoding. Next, we will refine the system with optimizations, including speed, safety, and cost-saving.

#### Speed optimization: parallelize video uploading

Uploading a video as a whole unit is inefficient. We can split a video into smaller chunks by GOP alignment as shown in Figure 22.

![Split Video by GOP](images/15-design-YouTube/figure22-split-video-gop.svg)

*Figure 22: Split Video by GOP Alignment*

This allows fast resumable uploads when the previous upload failed. The job of splitting a video file by GOP can be implemented by the client to improve the upload speed as shown in Figure 23.

![Client-Side Video Splitting](images/15-design-YouTube/figure23-client-side-splitting.png)

*Figure 23: Client-Side Video Splitting*

#### Speed optimization: place upload centers close to users

Another way to improve the upload speed is by setting up multiple upload centers across the globe (Figure 24). People in the United States can upload videos to the North America upload center, and people in China can upload videos to the Asian upload center. To achieve this, we use CDN as upload centers.

![Global Upload Centers](images/15-design-YouTube/figure24-global-upload-centers.svg)

*Figure 24: Global Upload Centers*

#### Speed optimization: parallelism everywhere

Achieving low latency requires serious efforts. Another optimization is to build a loosely coupled system and enable high parallelism.

Our design needs some modifications to achieve high parallelism. Let us zoom in to the flow of how a video is transferred from original storage to the CDN. The flow is shown in Figure 25, revealing that the output depends on the input of the previous step. This dependency makes parallelism difficult.

![Sequential Video Processing](images/15-design-YouTube/figure25-sequential-processing.svg)

*Figure 25: Sequential Video Processing Flow*

To make the system more loosely coupled, we introduced message queues as shown in Figure 26. Let us use an example to explain how message queues make the system more loosely coupled.

- Before the message queue is introduced, the encoding module must wait for the output of the download module.
- After the message queue is introduced, the encoding module does not need to wait for the output of the download module anymore. If there are events in the message queue, the encoding module can execute those jobs in parallel.

![Parallel Processing with Message Queues](images/15-design-YouTube/figure26-parallel-processing.svg)

*Figure 26: Parallel Processing with Message Queues*

#### Safety optimization: pre-signed upload URL

Safety is one of the most important aspects of any product. To ensure only authorized users upload videos to the right location, we introduce pre-signed URLs as shown in Figure 27.

![Pre-signed Upload URL](images/15-design-YouTube/figure27-presigned-url.png)

*Figure 27: Pre-signed Upload URL*

The upload flow is updated as follows:

1. The client makes a HTTP request to API servers to fetch the pre-signed URL, which gives the access permission to the object identified in the URL. The term pre-signed URL is used by uploading files to Amazon S3. Other cloud service providers might use a different name. For instance, Microsoft Azure blob storage supports the same feature, but call it "Shared Access Signature" [10].
2. API servers respond with a pre-signed URL.
3. Once the client receives the response, it uploads the video using the pre-signed URL.

#### Safety optimization: protect your videos

Many content makers are reluctant to post videos online because they fear their original videos will be stolen. To protect copyrighted videos, we can adopt one of the following three safety options:

1. **Digital rights management (DRM) systems:** Three major DRM systems are Apple FairPlay, Google Widevine, and Microsoft PlayReady.
2. **AES encryption:** You can encrypt a video and configure an authorization policy. The encrypted video will be decrypted upon playback. This ensures that only authorized users can watch an encrypted video.
3. **Visual watermarking:** This is an image overlay on top of your video that contains identifying information for your video. It can be your company logo or company name.

#### Cost-saving optimization

CDN is a crucial component of our system. It ensures fast video delivery on a global scale. However, from the back of the envelope calculation, we know CDN is expensive, especially when the data size is large. How can we reduce the cost?

Previous research shows that YouTube video streams follow long-tail distribution [11] [12]. It means a few popular videos are accessed frequently but many others have few or no viewers. Based on this observation, we implement a few optimizations:

1. Only serve the most popular videos from CDN and other videos from our high capacity storage video servers (Figure 28).

![CDN vs Video Servers](images/15-design-YouTube/figure28-cdn-vs-servers.png)

*Figure 28: CDN vs Video Servers*

2. For less popular content, we may not need to store many encoded video versions. Short videos can be encoded on-demand.
3. Some videos are popular only in certain regions. There is no need to distribute these videos to other regions.
4. Build your own CDN like Netflix and partner with Internet Service Providers (ISPs). Building your CDN is a giant project; however, this could make sense for large streaming companies. An ISP can be Comcast, AT&T, Verizon, or other internet providers. ISPs are located all around the world and are close to users. By partnering with ISPs, you can improve the viewing experience and reduce the bandwidth charges.

All those optimizations are based on content popularity, user access pattern, video size, etc. It is important to analyze historical viewing patterns before doing any optimization. Here are some of the interesting articles on this topic: [12] [13].

### Error handling

For a large-scale system, system errors are unavoidable. To build a highly fault-tolerant system, we must handle errors gracefully and recover from them fast. Two types of errors exist:

- **Recoverable error.** For recoverable errors such as video segment fails to transcode, the general idea is to retry the operation a few times. If the task continues to fail and the system believes it is not recoverable, it returns a proper error code to the client.
- **Non-recoverable error.** For non-recoverable errors such as malformed video format, the system stops the running tasks associated with the video and returns the proper error code to the client.

Typical errors for each system component are covered by the following playbook:

- **Upload error:** retry a few times.
- **Split video error:** if older versions of clients cannot split videos by GOP alignment, the entire video is passed to the server. The job of splitting videos is done on the server-side.
- **Transcoding error:** retry.
- **Preprocessor error:** regenerate DAG diagram.
- **DAG scheduler error:** reschedule a task.
- **Resource manager queue down:** use a replica.
- **Task worker down:** retry the task on a new worker.
- **API server down:** API servers are stateless so requests will be directed to a different API server.
- **Metadata cache server down:** data is replicated multiple times. If one node goes down, you can still access other nodes to fetch data. We can bring up a new cache server to replace the dead one.
- **Metadata DB server down:**
  - Master is down. If the master is down, promote one of the slaves to act as the new master.
  - Slave is down. If a slave goes down, you can use another slave for reads and bring up another database server to replace the dead one.

## Step 4 - Wrap up

In this chapter, we presented the architecture design for video streaming services like YouTube. If there is extra time at the end of the interview, here are a few additional points:

- **Scale the API tier:** Because API servers are stateless, it is easy to scale API tier horizontally.
- **Scale the database:** You can talk about database replication and sharding.
- **Live streaming:** It refers to the process of how a video is recorded and broadcasted in real time. Although our system is not designed specifically for live streaming, live streaming and non-live streaming have some similarities: both require uploading, encoding, and streaming. The notable differences are:
  - Live streaming has a higher latency requirement, so it might need a different streaming protocol.
  - Live streaming has a lower requirement for parallelism because small chunks of data are already processed in real-time.
  - Live streaming requires different sets of error handling. Any error handling that takes too much time is not acceptable.
- **Video takedowns:** Videos that violate copyrights, pornography, or other illegal acts shall be removed. Some can be discovered by the system during the upload process, while others might be discovered through user flagging.

Congratulations on getting this far! Now give yourself a pat on the back. Good job!

## Reference materials

[1] YouTube by the numbers: https://www.omnicoreagency.com/youtube-statistics/

[2] 2019 YouTube Demographics: https://blog.hubspot.com/marketing/youtube-demographics

[3] Cloudfront Pricing: https://aws.amazon.com/cloudfront/pricing/

[4] Netflix on AWS: https://aws.amazon.com/solutions/case-studies/netflix/

[5] Akamai homepage: https://www.akamai.com/

[6] Binary large object: https://en.wikipedia.org/wiki/Binary_large_object

[7] Here's What You Need to Know About Streaming Protocols: https://www.dacast.com/blog/streaming-protocols/

[8] SVE: Distributed Video Processing at Facebook Scale: https://www.cs.princeton.edu/~wlloyd/papers/sve-sosp17.pdf

[9] Weibo video processing architecture (in Chinese): https://www.upyun.com/opentalk/399.html

[10] Delegate access with a shared access signature: https://docs.microsoft.com/en-us/rest/api/storageservices/delegate-access-with-shared-access-signature

[11] YouTube scalability talk by early YouTube employee: https://www.youtube.com/watch?v=w5WVu624fY8

[12] Understanding the characteristics of internet short video sharing: A youtube-based measurement study. https://arxiv.org/pdf/0707.3670.pdf

[13] Content Popularity for Open Connect: https://netflixtechblog.com/content-popularity-for-open-connect-b86d56f613b

