import java.io.IOException;
import java.util.StringTokenizer;
import java.util.HashMap;
import java.util.regex.Pattern;

import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.io.FloatWritable;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class PageRankInitializer {
    public static class PageRankInitializerMapper
        extends Mapper<Object, Text, Text, FloatWritable> {

        public void map(Object key, Text value, Context context
                       ) throws IOException, InterruptedException {
            String doc_id = value.toString().substring(0, value.toString().indexOf("\t"));
            String outLinksList = value.toString().substring(value.toString().indexOf("\t") + 1);
            String[] outLinks = outLinksList.split(" ", 0);

            if (outLinks.length > 0) {
                FloatWritable outLinksWeight = new FloatWritable(1 / outLinks.length);
                for (String outLink : outLinks) {
                    if (!outLink.isEmpty()) {
                        context.write(new Text(outLink), outLinksWeight);
                    }
                }
            }
        }
    }

    public static class PageRankInitializerReducer
        extends Reducer<Text, FloatWritable, Text, FloatWritable> {

        public void reduce(Text key, Iterable<FloatWritable> values, Context context
                          ) throws IOException, InterruptedException {
            float total_sum = 0.f;
            for (FloatWritable val : values) {
                total_sum += val.get();
            }
            float pagerank = (1 - .15f)/3 + .15f*total_sum;

            context.write(key, new FloatWritable(pagerank));
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "pagerank initializer");
        job.setJarByClass(PageRankInitializer.class);
        job.setMapperClass(PageRankInitializerMapper.class);
        job.setReducerClass(PageRankInitializerReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(FloatWritable.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
