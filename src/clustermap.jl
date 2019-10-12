@userplot Clustermap

recipetype(::Val{:clustermap}, args...) = Clustermap(args)

@recipe function f(cm::Clustermap)
    if length(cm.args) == 3
        M, hc, ticklabels = cm.args
    elseif length(cm.args) == 2
        M, hc = cm.args
        ticklabels = 1:nnodes(hc)
    end

    layout --> @layout [
        topdendrogram      _
        heatmap{0.9w,0.9h} rightdendrogram
    ]

    legend := false
    link := :both
    margin --> 0mm
    grid --> false

    @series begin
        seriestype := :heatmap
        subplot := 2
        ticks --> (1:nnodes(hc), ticklabels[hc.order])
        # TODO The colorbar is placed on the right hand side of the heatmap subplot. This
        # squashes the heatmap, which makes the topdendrogram be misaligned. Is it possible
        # to add the colorbar to the empty top-right subplot?
        # colorbar --> true
        M[hc.order, hc.order]
    end

    axis := :off

    # topdendrogram
    @series begin
        subplot := 1
        hc
    end

    # rightdendrogram
    @series begin
        subplot := 3
        horizontal := true
        hc
    end
end
